package Koha::App::GetIt;

use strict;
use warnings;

use JSON;
use CGI;
use LWP::UserAgent;
use HTTP::Request;
use HTTP::Request::Common;
use URI::Escape;
use C4::Context;

# {{{ Documentation
#
# Copyright 2013 LibLime
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

=head1 NAME

C4::Service::GetIt - RESTful interface to GetIt

=head1 SYNOPSIS

my $svc = C4::Service::GetIt->new();
$svc->post("/controller",$data_hashref);
$svc->put("/controller", $rec, $data_hashref);

=head1 DESCRIPTION

This module implements RESTful queries to GetIt.  GetIt uses a path 
convention of /controller/<id>/view/<subid> for all RESTful requests.
For POST requests, the ID, view, and sub ID are typically missing,
i.e., POST /controller, though it is possible to specify a non-default
view (e.g., POST /controller/0/viewname).  For PUT, GET, and DELETE
requests, the record ID should be passed in the path.

=head1 METHODS
=cut
# }}}

# {{{ sub new
=head2 new

=over 4

    my $svc = new C4::Service::GetIt();

=back

Create a new GetIt REST request object.  Determines the base URL automatically,
and passes the CGISESSID cookie along to GetIt for auth purposes.

=cut
sub new {
    my $class = shift;
    $class = ref($class) || $class;
    my $self = shift || {};

    bless($self, $class);

    $self->{enabled} = C4::Context->preference("GetItAcquisitions");
    
    if ($self->{enabled}) {
        my $q = new CGI;
        my $url = $q->url;
        $url =~ s~^(\w+://[^/]+/).*~$1~;
        $self->{baseurl} = $url . 'getit';

        $self->{useragent} = LWP::UserAgent->new();
        $self->{useragent}->timeout(30);
        $self->{useragent}->cookie_jar({});

        my $session_id = $q->cookie(-name => 'CGISESSID');
        warn "Session ID = $session_id";
        $self->{cookie} = $q->cookie(-name => 'CGISESSID', -value => $session_id);

        $self->{headers} = {
            'Cookie'        => $self->{cookie},
            'Content-Type'  => 'application/json;charset=UTF8',
            'Pragma'        => 'no-cache',
            'Cache-Control' => 'no-cache',
            'cgisessid' => $session_id,
            'kohainitiated' => 1
        };
    }

    return($self);
}
# }}}
# {{{ sub enabled()
=head2 enabled

=over 4

    $svc->enabled()

=back

Returns true if GetIt is enabled according to system preferences

=cut

sub enabled {
    shift->{enabled};
}
# }}}

# {{{ sub get($controller, $id, $opts)
=head2 get

=over 4

    $svc->get($controller, $id, $opts);

=back

Issue a GET request.  Returns decoded JSON data on success, or
undef and error on failure.
$id is the primary key (record ID)
$opts is a hashref of options, including

=over 4
    'view' => $viewname (select a non-default view)
    'subid' => $id (include a subrecord ID)
    'query' => $hashref (GET query options)
=back

=cut

sub get {
    my $self = shift;
    my ($controller, $id, $opts) = @_;

    return(undef,"GetIt Acquisitions not available") unless ($self->{enabled});
    my (@path) = ($self->{baseurl}, $controller);
    push(@path, $id // '') if (defined($id) or defined($opts->{view}) or defined($opts->{subid}));
    push(@path, $opts->{view} // '') if (defined($opts->{view}) or defined($opts->{subid}));
    push(@path, $opts->{subid}) if (defined($opts->{subid}));
    my $url = join('/',@path);

    if (defined($opts->{query})) {
        my (@query);
        while (my ($f, $v) = each %{$opts->{query}}) {
            push(@query, "$f=" . uri_escape($v));
        }
        $url .= '?' . join('&', @query);
    }

    my $resp = $self->{useragent}->get($url, %{$self->{headers}});
    unless ($resp->is_success) {
        return(undef, 'Request failed: ' . $resp->status_line . ': ', $resp->content);
    }

    return decode_json($resp->content);
}

# }}}
# {{{ sub post($controller, $data, $opts)
=head2 post

=over 4

    $svc->post($controller, $data, $opts);

=back

Issue a POST request.  Returns object on success, undef and error on failure.
$data is a hashref to the object to post (to be JSON encoded).
$opts is a hashref of options, including

=over 4
    'view' => $viewname (select a non-default view)
=back

=cut


sub post {
    my $self = shift;
    my ($controller, $data, $opts) = @_;

    return(undef,"GetIt Acquisitions not available") unless ($self->{enabled});

    my (@path) = ($self->{baseurl}, $controller);
    push(@path, 0, $opts->{view}) if (defined($opts->{view}));
    my $url = join('/',@path);

    my $json = encode_json($data);
    my $resp = $self->{useragent}->post($url, %{$self->{headers}}, 'Content' => $json);
    unless ($resp->is_success) {
        return(undef, 'Request failed: ' . $resp->status_line . ': ', $resp->content);
    }

    return decode_json($resp->content);
}

# }}}
# {{{ sub put($controller, $id, $data, $opts)
=head2 put

=over 4

    $svc->put($controller, $id, $data, $opts);

=back

Issue a PUT request.  Returns object on success, undef and error on failure.
$id is the primary key (record ID)
$data is a hashref to the object to post (to be JSON encoded).
$opts is a hashref of options, including

=over 4
    'view' => $viewname (select a non-default view)
    'subid' => $id (include a subrecord ID)
=back

=cut

sub put {
    my $self = shift;
    my ($controller, $id, $data, $opts) = @_;

    return(undef,"GetIt Acquisitions not available") unless ($self->{enabled});

    my (@path) = ($self->{baseurl}, $controller, $id);
    push(@path, $opts->{view} // '') if (defined($opts->{view}) or defined($opts->{subid}));
    push(@path, $opts->{subid}) if (defined($opts->{subid}));
    my $url = join('/',@path);

    my $json = encode_json($data);
    my $resp = $self->{useragent}->request(HTTP::Request::Common::PUT($url, %{$self->{headers}}, 'Content' => $json));
    unless ($resp->is_success) {
        return(undef, 'Request failed: ' . $resp->status_line . ': ', $resp->content);
    }

    return decode_json($resp->content);
}

# }}}
# {{{ sub delete($controller, $id, $opts)
=head2 delete

=over 4

    $svc->delete($controller, $id, $opts);

=back

Issue a DELETE request.  Returns 1 on success, undef and error on failure.
$id is the primary key (record ID)
$opts is a hashref of options, including

=over 4
    'view' => $viewname (select a non-default view)
    'subid' => $id (include a subrecord ID)
=back

=cut

sub delete {
    my $self = shift;
    my ($controller, $id, $opts) = @_;

    return(undef,"GetIt Acquisitions not available") unless ($self->{enabled});

    my (@path) = ($self->{baseurl}, $controller, $id);
    push(@path, $opts->{view} // '') if (defined($opts->{view}) or defined($opts->{subid}));
    push(@path, $opts->{subid}) if (defined($opts->{subid}));
    my $url = join('/',@path);

    my $resp = $self->{useragent}->request(HTTP::Request::Common::DELETE($url, %{$self->{headers}}));
    unless ($resp->is_success) {
        return(undef, 'Request failed: ' . $resp->status_line . ': ', $resp->content);
    }
    return 1;
}

# }}}

1;

__END__

=head1 AUTHORS

Koha Development Team

William White <frogomatic@gmail.com>
