#!/usr/bin/env perl

# Copyright 2007 Liblime Ltd
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

# Script to take some borrowers data in a known format and load it into Koha
#
# File format
#
# cardnumber,surname,firstname,title,othernames,initials,streetnumber,streettype,
# address line , address line 2, city, zipcode, contry, email, phone, mobile, fax, work email, work phone,
# alternate streetnumber, alternate streettype, alternate address line 1, alternate city,
# alternate zipcode, alternate country, alternate email, alternate phone, date of birth, branchcode,
# categorycode, enrollment date, expiry date, noaddress, lost, debarred, contact surname,
# contact firstname, contact title, borrower notes, contact relationship, ethnicity, ethnicity notes
# gender, username, opac note, contact note, password, sort one, sort two
#
# any fields except cardnumber can be blank but the number of fields must match
# dates should be in the format you have set up Koha to expect
# branchcode and categorycode need to be valid

use strict;
use warnings;

use C4::Auth;
use C4::Output;
use Koha;
use C4::Context;
use C4::Members::Import;
use C4::Branch qw(GetBranchName GetBranches);
use C4::Members;
use C4::Members::Attributes qw(:all);
use C4::Members::AttributeTypes;
use C4::Members::Messaging;

use Text::CSV;
# Text::CSV::Unicode, even in binary mode, fails to parse lines with these diacriticals:
# ė
# č

use CGI;
# use encoding 'utf8';    # don't do this

my (@errors, @feedback);
my $extended = C4::Context->preference('ExtendedPatronAttributes');
my $set_messaging_prefs = C4::Context->preference('EnhancedMessagingPreferences');
my @columnkeys = C4::Members->columns;
if ($extended) {
    push @columnkeys, 'patron_attributes';
}
my $columnkeystpl = [ map { {'key' => $_} }  grep {$_ ne 'borrowernumber' && $_ ne 'cardnumber'} @columnkeys ];  # ref. to array of hashrefs.

my $input = CGI->new();
our $csv  = Text::CSV->new({binary => 1});  # binary needed for non-ASCII Unicode
# push @feedback, {feedback=>1, name=>'backend', value=>$csv->backend, backend=>$csv->backend};

my ( $template, $loggedinuser, $cookie ) = get_template_and_user({
        template_name   => "tools/import_borrowers.tmpl",
        query           => $input,
        type            => "intranet",
        authnotrequired => 0,
        flagsrequired   => { tools => 'import_patrons' },
        debug           => 1,
});

$template->param(columnkeys => $columnkeystpl);

if ($input->param('sample')) {
    print $input->header(
        -type       => 'application/vnd.sun.xml.calc', # 'application/vnd.ms-excel' ?
        -attachment => 'patron_import.csv',
    );
    $csv->combine(@columnkeys);
    print $csv->string, "\n";
    exit;
}
my $uploadborrowers = $input->param('uploadborrowers');
my $matchpoint      = $input->param('matchpoint');
if ($matchpoint) {
    $matchpoint =~ s/^patron_attribute_//;
}
my $overwrite_cardnumber = $input->param('overwrite_cardnumber');
$template->param( SCRIPT_NAME => $ENV{'SCRIPT_NAME'} );
($extended) and $template->param(ExtendedPatronAttributes => 1);

# FIXME : this tool will currently allow patrons to be imported to any library, uncontrolled by Independent branches.
my $branches=GetBranches();

if ( $uploadborrowers && length($uploadborrowers) > 0 ) {
    my %retval = C4::Members::Import::ImportFromFH($input->upload('uploadborrowers'),
					   $matchpoint,
					   $overwrite_cardnumber,
					   $input->param('ext_preserve'),
					   scalar $input->Vars());

    $template->param(  ERRORS=>$retval{errors}  );
    $template->param(FEEDBACK=>$retval{feedback});
    $template->param(
        'uploadborrowers' => 1,
	'lastimported'    => $retval{lastimported},
	'lastoverwritten' => $retval{lastoverwritten},
	'lastalreadyindb' => $retval{lastalreadyindb},
	'lastinvalid'     => $retval{lastinvalid},
        'imported'        => $retval{imported},
        'overwritten'     => $retval{overwritten},
        'alreadyindb'     => $retval{alreadyindb},
        'invalid'         => $retval{invalid},
        'total'           => $retval{imported} + $retval{alreadyindb} +
	                     $retval{invalid} + $retval{overwritten},
    );

} else {
    if ($extended) {
        my @matchpoints = ();
        my @attr_types = C4::Members::AttributeTypes::GetAttributeTypes();
        foreach my $type (@attr_types) {
            my $attr_type = C4::Members::AttributeTypes->fetch($type->{code});
            if ($attr_type->unique_id()) {
            push @matchpoints, { code =>  "patron_attribute_" . $attr_type->code(), description => $attr_type->description() };
            }
        }
        $template->param(matchpoints => \@matchpoints);
    }
}

output_html_with_http_headers $input, $cookie, $template->output;

