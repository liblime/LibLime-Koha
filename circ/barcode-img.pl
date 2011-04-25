#!/usr/bin/perl


# Copyright 2008 LibLime
#
# Copyright 2011 LibLime, a Division of PTFS, Inc.
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
use C4::Context;
use CGI;
use CGI::Session;
use C4::Auth qw/check_cookie_auth/;
use CGI::Cookie; # need to check cookies before having CGI parse the POST request
use GD::Barcode;

my $input = new CGI;
my %cookies = fetch CGI::Cookie;
my ($auth_status, $sessionID) = check_cookie_auth($cookies{'CGISESSID'}->value, { circulate => '*' });

if ($auth_status ne "ok") {
    my $reply = CGI->new("");
    print $reply->header(-type => 'text/html');    print "{}";
    exit 0;
}
my $barcode = $input->param('barcode');

my $reply = CGI->new('');
#FIXME: Allow setting barcode type here.
my $oGdBar = GD::Barcode->new('Code39', $barcode );

if($oGdBar && $barcode) {
    print $reply->header(-type => 'image/png');
    print $oGdBar->plot->png;
} else {
    print $reply->header(-type => 'text/html');
    print $GD::Barcode::errStr;
}
exit 0;
