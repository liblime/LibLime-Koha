package Koha::Money;

use Koha;
use Method::Signatures;
use Math::BigFloat;

use vars qw(@ISA $round_mode);

BEGIN {
    @ISA = qw(Math::BigFloat);
    $round_mode = 'even';
}

method value(%opt) {
    # TODO: Add system pref for currency symbols & placement.
    return ($opt{'use_symbol'}) ? sprintf("\$%.2f",$self->bfround(-2)->bstr()) : sprintf("%.2f",$self->bfround(-2)->bstr());
}


1;

