package C4::Members::Import;

# Copyright 2010 PTFS, Inc.
#
# This file is part of Koha.
#
# Koha is free software; you can redistribute it and/or modify it under the
# terms of the GNU General Public License as published by the Free Software
# Foundation; either version 2 of the License, or (at your option) any later
# version.
#
# Koha is distributed in the hope that it will be useful, but WITHOUT ANY
# WARRANTY; without even the implied warranty of MERCHANTABILITY or FITNESS FOR
# A PARTICULAR PURPOSE.  See the GNU General Public License for more details.
#
# You should have received a copy of the GNU General Public License along with
# Koha; if not, write to the Free Software Foundation, Inc., 59 Temple Place,
# Suite 330, Boston, MA  02111-1307 USA


use strict;

use Carp;
use Try::Tiny;

use C4::Branch;
use C4::Dates qw(format_date_in_iso);

our ($VERSION,@ISA,@EXPORT,@EXPORT_OK,$debug);

BEGIN {
	$VERSION = 3.02;
	$debug = $ENV{DEBUG} || 0;
	require Exporter;
	@ISA = qw(Exporter);
	#Get data
	push @EXPORT, qw(
                &ImportFromFH
        );
}

=head1 NAME

C4::Members::Import - Import utilities for patron data

=head1 SYNOPSIS

use C4::Members;

=head1 DESCRIPTION

This module contains routines for adding, modifying and deleting members/patrons/borrowers 

=head1 FUNCTIONS

=over 2

=item ImportFromFH

=back

ImportFromFH($handle, $matchpoint, $overwrite_cardnumber, $ext_preserve, $defaults);

imports new borrower records from a file handle

return :
A hash of statistics and logs relating to the import process

=cut

use C4::Members;
use C4::Members::Attributes qw(:all);
use C4::Members::AttributeTypes;
use C4::Members::Messaging;

sub ImportFromFH {
    my ($handle, $matchpoint, $overwrite_cardnumber, $ext_preserve, $defaults) = @_;
    my (%retval, @errors, @feedback);

    $retval{imported} = 0;
    $retval{overwritten} = 0;
    $retval{alreadyindb} = 0;
    $retval{invalid} = 0;

    my $extended = C4::Context->preference('ExtendedPatronAttributes');
    my $set_messaging_prefs = C4::Context->preference('EnhancedMessagingPreferences');
    my @columnkeys = C4::Members->columns;
    if ($extended) {
	push @columnkeys, 'patron_attributes';
    }
    my $columnkeystpl = [ map { {'key' => $_} }  grep {$_ ne 'borrowernumber' && $_ ne 'cardnumber'} @columnkeys ];  # ref. to array of hashrefs.
    our $csv  = Text::CSV->new({binary => 1});  # binary needed for non-ASCII Unicode
    if ($matchpoint) {
	$matchpoint =~ s/^patron_attribute_//;
    }
    # FIXME : this tool will currently allow patrons to be imported to any library, uncontrolled by Independent branches.
    my $branches=GetBranches();

    my $matchpoint_attr_type; 

    # use header line to construct key to column map
    my $borrowerline = <$handle>;
    my $status = $csv->parse($borrowerline);
    ($status) or push @errors, {badheader=>1,line=>$., lineraw=>$borrowerline};
    my @csvcolumns = $csv->fields();
    my %csvkeycol;
    my $col = 0;
    foreach my $keycol (@csvcolumns) {
    	# columnkeys don't contain whitespace, but some stupid tools add it
    	$keycol =~ s/ +//g;
        $csvkeycol{$keycol} = $col++;
    }
    if ($extended) {
        $matchpoint_attr_type = C4::Members::AttributeTypes->fetch($matchpoint);
    }
    push @feedback, {feedback=>1, name=>'headerrow', value=>join(', ', @csvcolumns)};
    my $today_iso = C4::Dates->new()->output('iso');
    my @criticals = qw(surname branchcode categorycode);    # there probably should be others
    my @bad_dates;  # I've had a few.
    my $date_re = C4::Dates->new->regexp('syspref');
    my  $iso_re = C4::Dates->new->regexp('iso');

    LINE: while ( my $borrowerline = <$handle> ) {
        my %borrower;
        my @missing_criticals;
        my $patron_attributes;
        my $status  = $csv->parse($borrowerline);
        my @columns = $csv->fields();
        if (! $status) {
            push @missing_criticals, {badparse=>1, line=>$., lineraw=>$borrowerline} unless @missing_criticals;
        } elsif (@columns == @columnkeys) {
            @borrower{@columnkeys} = @columns;
            # MJR: try to fill blanks gracefully by using default values
            foreach my $key (@criticals) {
                if ($borrower{$key} !~ /\S/) {
                    $borrower{$key} = $defaults->{$key};
                }
            } 
        } else {
            # MJR: try to recover gracefully by using default values
            foreach my $key (@columnkeys) {
            	if (defined($csvkeycol{$key}) and $columns[$csvkeycol{$key}] =~ /\S/) { 
            	    $borrower{$key} = $columns[$csvkeycol{$key}];
            	} elsif ( $defaults->{$key} ) {
            	    $borrower{$key} = $defaults->{$key};
            	} elsif ( scalar grep {$key eq $_} @criticals ) {
            	    # a critical field is undefined
            	    push @missing_criticals, {key=>$key, line=>$., lineraw=>$borrowerline} unless @missing_criticals;
            	} else {
            		$borrower{$key} = '';
            	}
            }
        }
        if ($borrower{categorycode}) {
            push @missing_criticals, {key=>'categorycode', line=>$. , lineraw=>$borrowerline, value=>$borrower{categorycode}, category_map=>1}
                unless GetBorrowercategory($borrower{categorycode}) or @missing_criticals;
        } else {
            push @missing_criticals, {key=>'categorycode', line=>$. , lineraw=>$borrowerline} unless @missing_criticals;
        }
        if ($borrower{branchcode}) {
            push @missing_criticals, {key=>'branchcode', line=>$. , lineraw=>$borrowerline, value=>$borrower{branchcode}, branch_map=>1}
                unless GetBranchName($borrower{branchcode}) or @missing_criticals;
        } else {
            push @missing_criticals, {key=>'branchcode', line=>$. , lineraw=>$borrowerline} unless @missing_criticals;
        }
        if (@missing_criticals) {
            foreach (@missing_criticals) {
                $_->{borrowernumber} = $borrower{borrowernumber} || 'UNDEF';
                $_->{surname}        = $borrower{surname} || 'UNDEF';
            }
            $retval{invalid}++;
	    $retval{lastinvalid} = $borrower{surname}.' / '.$borrower{borrowernumber} ;
            (25 > scalar @errors) and push @errors, {missing_criticals=>\@missing_criticals};
            # The first 25 errors are enough.  Keeping track of 30,000+ would destroy performance.
            next LINE;
        }
        if ($extended) {
            my $attr_str = $borrower{patron_attributes};
            delete $borrower{patron_attributes};    # not really a field in borrowers, so we don't want to pass it to ModMember.
            $patron_attributes = extended_attributes_code_value_arrayref($attr_str); 
        }
	# Popular spreadsheet applications make it difficult to force date outputs to be zero-padded, but we require it.
        foreach (qw(dateofbirth dateenrolled dateexpiry)) {
            my $tempdate = $borrower{$_} or next;
            if ($tempdate =~ /$date_re/) {
                $borrower{$_} = format_date_in_iso($tempdate);
            } elsif ($tempdate =~ /$iso_re/) {
                $borrower{$_} = $tempdate;
            } else {
                $borrower{$_} = '';
                push @missing_criticals, {key=>$_, line=>$. , lineraw=>$borrowerline, bad_date=>1} unless @missing_criticals;
            }
        }
	$borrower{dateenrolled} = $today_iso unless $borrower{dateenrolled};
	$borrower{dateexpiry} = GetExpiryDate($borrower{categorycode},$borrower{dateenrolled}) unless $borrower{dateexpiry}; 
        my $borrowernumber;
        my $member;
        if ( ($matchpoint eq 'cardnumber') && ($borrower{'cardnumber'}) ) {
            $member = C4::Members::GetMember( $borrower{'cardnumber'}, 'cardnumber' );
            if ($member) {
                $borrowernumber = $member->{'borrowernumber'};
            }
        } elsif ($extended) {
            if (defined($matchpoint_attr_type)) {
                foreach my $attr (@$patron_attributes) {
                    if ($attr->{code} eq $matchpoint and $attr->{value} ne '') {
                        my @borrowernumbers = $matchpoint_attr_type->get_patrons($attr->{value});
                        if(scalar(@borrowernumbers) == 1){
                            $borrowernumber = $borrowernumbers[0];
                            $member = C4::Members::GetMember($borrowernumber, 'borrowernumber');
                        }
                        last;
                    }
                }
            }
        }
            
        if ($borrowernumber) {
            # borrower exists
            unless ($overwrite_cardnumber) {
                $retval{alreadyindb}++;
		$retval{lastalreadyindb} = $borrower{surname}.' / '.$borrowernumber ;
                next LINE;
            }
            $borrower{'borrowernumber'} = $borrowernumber;
            for my $col (keys %borrower) {
                # use values from extant patron unless our csv file includes this column or we provided a default.
                # FIXME : You cannot update a field with a  perl-evaluated false value using the defaults.
                unless(exists($csvkeycol{$col}) || $defaults->{$col}) {
                    $borrower{$col} = $member->{$col} if($member->{$col}) ;
                }
            }
            unless (ModMember(%borrower)) {
                $retval{invalid}++;
                $retval{lastinvalid} = $borrower{surname}.' / '.$borrower{borrowernumber} ;
                next LINE;
            }
            if ($extended) {
                if ($ext_preserve) {
                    my $old_attributes = GetBorrowerAttributes($borrowernumber);
                    $patron_attributes = extended_attributes_merge($old_attributes, $patron_attributes);  #TODO: expose repeatable options in template
                }
                SetBorrowerAttributes($borrower{'borrowernumber'}, $patron_attributes);
            }
            $retval{overwritten}++;
            $retval{lastoverwritten} = $borrower{surname}.' / '.$borrowernumber ;
        } else {
            # FIXME: fixup_cardnumber says to lock table, but the web interface doesn't so this doesn't either.
            # At least this is closer to AddMember than in members/memberentry.pl
            if (!$borrower{'cardnumber'}) {
                $borrower{'cardnumber'} = fixup_cardnumber(undef,$branches->{$borrower{'branchcode'}});
            }
            $borrowernumber = try {
                    AddMember(%borrower);
                } catch {
                    carp "AddMember failed: $@\n";
                    undef;
                };
            if ($borrowernumber) {
                if ($extended) {
                    SetBorrowerAttributes($borrowernumber, $patron_attributes);
                }
                if ($set_messaging_prefs) {
                    C4::Members::Messaging::SetMessagingPreferencesFromDefaults({ borrowernumber => $borrowernumber,
                                                                                  categorycode => $borrower{categorycode} });
                }
                $retval{imported}++;
                $retval{lastimported} = $borrower{surname}.' / '.$borrowernumber ;
            } else {
                $retval{invalid}++;
                $retval{lastinvalid} = $borrower{surname}.' / '.$borrowernumber ;
            }
        }
    }

    $retval{feedback} = \@feedback;
    $retval{errors} = \@errors;

    return (%retval);
}


END { }    # module clean-up code here (global destructor)

1;

__END__

=head1 AUTHOR

Koha Team

=cut
