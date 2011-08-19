package ILS::Transaction::RealtimeUpdate;

use warnings;
use strict;

use Sys::Syslog qw(syslog);

use ILS;
use ILS::Transaction;

use C4::Letters;

our @ISA = qw(ILS::Transaction);

my %fields = ();

sub new {
  my $class = shift;
  my $self  = $class->SUPER::new();

  foreach ( keys %fields ) {
    $self->{_permitted}->{$_} = $fields{$_};
  }

  syslog("LOG_DEBUG", "ILS::Transaction::RealtimeUpdate");

  @{$self}{ keys %fields } = values %fields;
  return bless $self, $class;
}

sub create_print_notice ($$$) {
  my $self = shift;
  my $borrower = shift;
  my $item = shift;

  syslog("LOG_DEBUG", "ILS::Transaction::RealtimeUpdate::create_print_notice");
  my $letter = getletter('reserves','HOLD_PRINT');
  C4::Letters::parseletter($letter,'borrowers',$borrower);
  C4::Letters::parseletter($letter,'branches',$item->{holdingbranch});
  C4::Letters::parseletter($letter,'biblio',$item->{biblionumber});
  C4::Letters::parseletter($letter,'reserves',$borrower,$item->{biblionumber});
  C4::Letters::EnqueueLetter( {
    letter => $letter,
    borrowernumber => $borrower,
    message_transport_type => 'print',
  } );

  return $self;
}

1;
