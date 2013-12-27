package ILS::Transaction::FeePayment;

use warnings;
use strict;

# Copyright 2011 PTFS-Europe Ltd.
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
# You should have received a copy of the GNU General Public License along
# with Koha; if not, write to the Free Software Foundation, Inc.,
# 51 Franklin Street, Fifth Floor, Boston, MA 02110-1301 USA.

use C4::Accounts;
use C4::Items;
use ILS;
use base qw(ILS::Transaction);

use vars qw($VERSION @ISA $debug);

our $debug   = 0;
our $VERSION = 1.00;

my %fields = ();

sub new {
    my $class = shift;
    my $self  = $class->SUPER::new();

    foreach ( keys %fields ) {
        $self->{_permitted}->{$_} = $fields{$_};    # overlaying_permitted
    }

    @{$self}{ keys %fields } = values %fields;    # copying defaults into object
    return bless $self, $class;
}

sub pay {
    my $self           = shift;
    my $borrowernumber = shift;
    my $amt            = shift;
    my $barcode        = shift;
    my $credit = { 
                borrowernumber  => $borrowernumber,
                description     => "Payment accepted via SIP2",
                amount          => sprintf("%.2f",$amt),
                accounttype     => 'PAYMENT',
            };
    my @fees_to_pay;
    if ($barcode) {
        my $itemnumber = C4::Items::GetItemnumberFromBarcode($barcode);
        my $fees = C4::Accounts::getcharges($borrowernumber, outstanding=>1, itemnumber=>$itemnumber);          
        for my $fee (@$fees) {
          push @fees_to_pay,$fee->{fee_id};
        }
        C4::Accounts::manualcredit($credit, fees => \@fees_to_pay);
    }
    else {
        C4::Accounts::manualcredit($credit);
    }
}

#sub DESTROY {
#}

1;
__END__

