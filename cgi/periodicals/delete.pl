#!/usr/bin/env perl

use warnings;
use strict;
use Carp;
use CGI;

use C4::Auth;
use C4::Output;
use C4::View::Serials;

my $query = CGI->new();
my ($template, $loggedinuser, $cookie) = 
    get_template_and_user({template_name => "periodicals/delete.tmpl",
                           query => $query,
                           type => "intranet",
                           authnotrequired => 0,
                           flagsrequired => {serials => 'periodical_delete'},
                           debug => 1,
                          });

my $id = $query->param('id') or croak 'No ID specified';
my $type = $query->param('type') or croak 'No type specified';
my $parent = $query->param('parent');

my %jump = (
    periodical => {camel => 'Periodical', human => 'periodical', redir => 'periodicals-home.pl'},
    periodical_serial => {camel => 'PeriodicalSerial', human => 'periodical-serial', redir => 'periodicals-detail.pl?periodical_id=%s'},
    subscription => {camel => 'Subscription', human => 'subscription', redir => 'periodicals-detail.pl?periodical_id=%s'},
    subscription_serial => {camel => 'SubscriptionSerial', human => 'subscription-serial', redir => 'subscription-detail.pl?subscription_id=%s'},
);

croak 'Unrecognized object type' if not exists $jump{$type};
my $delete_func = \&{"C4::Control::$jump{$type}{camel}::Delete"};
my $seed_func = \&{"C4::View::Serials::SeedTemplateWith$jump{$type}{camel}Data"};

if (defined $query->param('confirmed')) {
    eval "use C4::Control::$jump{$type}{camel}";
    $parent = &{$delete_func}($id);
    my $redir = $jump{$type}{redir};
    $redir =~ s/%s/$parent/; 
    print $query->redirect($redir);
}
else {
    &{$seed_func}($template, $id);
    C4::View::Serials::SeedTemplateWithGeneralData($template);
    $template->param(type => $type, type_human => $jump{$type}{human}, id => $id);
    output_html_with_http_headers $query, $cookie, $template->output;
}

exit 0;
