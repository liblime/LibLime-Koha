#!/usr/bin/env perl
#-----------------------------------
# Copyright (c) Jesse Weaver, 2009
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
#-----------------------------------

=head1 NAME

debt_collect.pl - submit debt collection reports to a collections agency

=head1 DESCRIPTION

When run, this will find patrons that have to be sent to a collections agency.
It will add a fine to their accounts, then mark them as sent. For patrons that
have already been sent to the collections agency, a separate report will be
prepared detailing what fines have been paid or added.

=head1 SYNOPSIS

debt_collect.pl [ --confirm ] [ -v | --verbose ] ...

 Options:
   -h | --help                 Print out help text
   --usage                     Print out a short usage message
   -c | --confirm              Send the reports, don't just show them
   -v | --verbose              Show the reports that would be sent
   -l | --library LIBRARY_CODE Only report patrons from this library
   -f | --fine COLLECTION_FINE Charge this much to patrons that are reported
   -o | --once [DESCRIPTION]   Don't charge sent to collection fee twice
   -w | --wait DAYS            How many days to wait to report patron
   --max-wait DAYS             Ignore patrons after this many days old
   --to EMAIL                  Send the reports to this email address
   --subject SUBJECT           Subject of the sent email
   --ignore PATRON_TYPE        Ignore borrowers of this type

=head1 OPTIONS

=over 8

=item B<-h|--help>

Print out help page for this script.

=item B<--usage>

Print out a short usage message, and exit.

=item B<-c|--confirm>

Do actually send the reports to the collections agency. If this is not
specified, --verbose is turned on, so you can see the reports that would be
sent, and the reports are not emailed.

=item B<-v|--verbose>

Show the reports that are being sent what fees are being charged to the
patrons. On by default unless --confirm is specified.

=item B<-l|--library>

Only send patrons from a specific library to the debt collections agency,
rather than those from all libraries. Should specify a library code.

=item B<-f|--fine>

Charge this amount to patrons that are sent to the debt collections agency. If
this is not specified, no fine will be charged. Should specify an amount.

=item B<-o|--once>

If this option is passed, only charge the debt collection fee once. If this
option has an argument, it should be a description of the fine to ignore (in
addition to the default).

=item B<--to>

Send the reports to this address. Can be specified multiple times, with an email
address each time.

=item B<-w|--wait>

How many days to wait, including holidays and weekends, after the last billing
notice to send the patron to a debt collection agency.

=item B<--subject>

Subject and body of submitted email.

=back

=cut

use strict;
use warnings;
BEGIN {
    # find Koha's Perl modules
    # test carefully before changing this
    use FindBin;
    eval { require "$FindBin::Bin/../kohalib.pl" };
}
use C4::Overdues::UniqueMgmt;
use C4::Branch qw( GetBranchName );
use C4::Circulation;
use C4::Overdues;
use C4::Accounts;
use C4::Members;
use C4::Letters;
use C4::Category;
use Koha::Money;

use Getopt::Long;
use Pod::Usage;

my ( $help, $usage, $branch, $verbose, $confirm, @to, @ignored, $once );

my $subject = 'Debt Collect';
my $wait = 21;
my $max_wait = 365;
my $send_fine = 10;

GetOptions(
    'h|help' => \$help,
    'usage' => \$usage,
    'l|library=s' => \$branch,
    'confirm' => \$confirm,
    'v|verbose' => \$verbose,
    'f|fine=f' => \$send_fine,
    'to=s' => \@to,
    'w|wait=i' => \$wait,
    'max-wait=i' => \$max_wait,
    'ignore=s' => \@ignored,
    'subject=s' => \$subject,
    'o|once' => \$once,
) or pod2usage( 2 );
pod2usage( 1 ) if ( $usage );
pod2usage( -verbose => 2 ) if ( $help );

if ( $branch && !GetBranchName( $branch ) ) {
    print "Invalid branch $branch, cannot continue\n";
    exit 1;
}

unless ( @to ) {
    print "Must specify email addresses with --to\n";
    exit 1;
}

unless ( $confirm ) {
    $verbose = 1;     # If you're not running it for real, then the whole point is the print output.
    print "### TEST MODE -- NO ACTIONS TAKEN ###\n";
}

my $today = C4::Dates->new()->output( 'iso' );
my %calendars;
my @submitted;
my @updated;

@ignored = split(/,/,join(',',@ignored));

my %categories = map { $_->categorycode => $_->{fines_alert_threshold}}  C4::Category->all();
my $acct_types = C4::Accounts::getaccounttypes();


# If $branch is not set, it is the same as not passing it
foreach my $borrower ( @{ GetNotifiedMembers( $wait, $max_wait, $branch, @ignored ) } ) {
    
    print "$borrower->{firstname} $borrower->{surname} ($borrower->{cardnumber}): " if ( $verbose );
    if ( $borrower->{exclude_from_collection} ) {
        print "manually skipped\n" if ( $verbose );
        next;
    }
    $borrower->{fines_alert_threshold} = $categories{$borrower->{categorycode}};
    
    my $totalowed = C4::Accounts::gettotalowed($borrower->{'borrowernumber'},C4::Context->preference('ExcludeAccruingInTotal'));

    my $last_reported_amt = Koha::Money->new($borrower->{last_reported_amount});

    if ( $borrower->{'last_reported_date'} && $last_reported_amt > 0 ){
        if ( $borrower->{'last_reported_date'} eq $today ) {
            print "skipping, already reported today\n" if ( $verbose );
            next;
        }
        if ( $totalowed == $borrower->{last_reported_amount}) {
            print "skipping, no difference\n" if ( $verbose );
            next;
        }
        if ( $totalowed < $borrower->{fines_alert_threshold} ) {
            C4::Members::ClearBillingFlags($borrower->{'borrowernumber'}) if ( $confirm );
        }
        print "updating\n" if ( $verbose );

        my $additional = Koha::Money->new();  # new fines
        my $paid = Koha::Money->new();  # new payments
        my $waived = C4::Accounts::get_total_waived_amount($borrower->{'borrowernumber'}, $borrower->{'last_reported_date'});
        my $returned = 0; # No reliable way to detect returned items at this time

        for my $fee ( @{C4::Accounts::getcharges($borrower->{'borrowernumber'}, since=>$borrower->{'last_reported_date'})} ) {
            $additional += $fee->{'amount'};  # Note we do the whole amount since waives and payments are included below.
        }
        for my $credit ( @{C4::Accounts::getpayments($borrower->{'borrowernumber'}, since=>$borrower->{'last_reported_date'})}){
            $paid += $credit->{amount};                
        }

        # If our numbers don't add up, cheat and adjust additional or paid.
        my $diff = $totalowed - $borrower->{last_reported_amount} - $additional - $paid - $waived;
        if($diff){
            $verbose and warn "Additional fees and payments did not add up to new totalowed.";
        }
        if($diff < 0){
            $paid += $diff;            
        } else {
            $additional += $diff;            
        }

        push @updated, AddBorrowerUpdate( {
            %$borrower,
            total => $totalowed->value,
            additional => $additional->value,
            returned => $returned,
            waived => $waived->value,
            paid => $paid->value,
        } );
           
    } else {
        if ( $totalowed < $borrower->{fines_alert_threshold} ) {
            print "skipping, has only $totalowed in fines\n" if ( $verbose );
            C4::Members::ClearBillingFlags($borrower->{'borrowernumber'}) if ( $confirm );
            next;
        }

         # Following original code here, we test for a collections fee that isn't resolved.
         # If the collections fee has been resolved, they get charged again.  This is probably /usually/ good enough.
         my $has_unpaid_collections_fee;
         if($once){
            for my $fee (@{C4::Accounts::getcharges($borrower->{'borrowernumber'}, accounttype=>'COLLECTIONS')}){
                $has_unpaid_collections_fee = 1 if($fee->{amountoutstanding});
            }             
         }

         if ( $confirm && !($once && $has_unpaid_collections_fee)){
            $verbose && warn "charging collections fee.";
            C4::Accounts::CreateFee({ 
                borrowernumber => $borrower->{borrowernumber},
                description    => 'Sent to collections agency', 
                accounttype    => 'COLLECTIONS', 
                amount         => Koha::Money->new($send_fine),
                branchcode     => $borrower->{branchcode},
            });
            $totalowed += $send_fine;
        }

        print "submitting\n" if ( $verbose );
        push @submitted, AddBorrowerSubmit( {
            %$borrower,
            total => $totalowed->value,
            earliest_due => GetEarliestDueDate( $borrower->{'borrowernumber'} ) || '',
        } );   
    }

    MarkMemberReported( $borrower->{'borrowernumber'}, $totalowed->value ) if ( $confirm );
}

my @attachments;

my $submitted_report = join( "\n", @submitted );

print "submitted: $submitted_report\n" if ( $verbose && $submitted_report );

push @attachments, { filename => 'submit.txt', type => 'text/plain', content => "# Koha submitted patrons for $today\n$submitted_report" } if ( $submitted_report );

my $updated_report = join( "\n", @updated );

print "updated: $updated_report\n" if ( $verbose && $updated_report );
push @attachments, { filename => 'update.txt', type => 'text/plain', content => "# Koha updated patrons for $today\n$updated_report" } if ( $updated_report );

exit unless ( $confirm && @attachments );

my $letter = {
    code => 'DEBT_COLLECT',
    title => $subject,
    content => $subject,
};

my $admin_email = C4::Context->preference('KohaAdminEmailAddress');
foreach my $email ( @to ) {
    print "sending reports to $email\n" if ( $verbose );

    C4::Letters::EnqueueLetter( {
        borrowernumber => undef,
        to_address => $email,
        from_address => $admin_email,
        letter => $letter,
        message_transport_type => 'email',
        attachments => \@attachments
    } );
}
