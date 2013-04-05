package Koha::Pager;

# Copyright 2012 PTFS/LibLime
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

use Koha;
use Method::Signatures;
use Moose;
use namespace::autoclean;
use CGI;
use Data::Pageset;


has pageset => ( is => 'rw', isa => 'Data::Pageset', handles => [qw( first last )] );
has offset_param => ( is => 'rw', isa => 'Str', default => 'offset' );
has url => ( is => 'rw', isa => 'Str', builder => '_get_url' );
has mode => ( is => 'rw', isa => 'Str', default => 'offset' ); # governs whether to page by pageset increment or by 1.
has extra_param => ( is => 'rw', isa => 'Str' );  # extra uri parameters.

# instantiate a Koha::Pager object with a Data::Pageset object or
# the params required for one, and get back an arrayref suitable
# for passing to koha template include.

# Requires page to be accessible via GET.

# usage example:
#


method BUILD ($args) {
    # If we didn't get a pageset object, try to build it from other args.
    if(!$self->pageset){
        $self->pageset(Data::Pageset->new($args));
    }
}

method _get_url {
    my $cgi = CGI->new();
    $cgi->delete($self->offset_param);
    $self->url( $cgi->url( -absolute => 1, -query => 1) );
 
}

method tmpl_loop {
    my @pager;
    for (@{$self->pageset->pages_in_set()}){
        push @pager,  { pg => $_ ,
                    pg_offset => ($self->mode eq 'offset') ? ($_-1)*$self->pageset->entries_per_page : $_,
                    current_page => ($_==$self->pageset->current_page)?1:0,
                  }
    }
    my $pageloop = { page_numbers => \@pager,
                     url => $self->url,
                     offset_param => $self->offset_param,
                     extra_param => $self->extra_param,
                     };
    if (defined $self->pageset->previous_page){
        $pageloop->{has_previous} = 1;
        if($self->mode eq 'offset'){
            $pageloop->{previous_page_offset} = $self->pageset->entries_per_page * ($self->pageset->previous_page - 1);
        } else {
            $pageloop->{previous_page_offset} = $self->pageset->previous_page;
        }
    }
    if ($self->pageset->next_page){
        if($self->mode eq 'offset'){
            $pageloop->{next_page_offset} = $self->pageset->entries_per_page * ($self->pageset->next_page - 1);
        } else {
            $pageloop->{next_page_offset} = $self->pageset->next_page;
        }
    }

    return [ $pageloop ];
}

1;
