use Koha;

#
# Copyright 2013 LibLime
#
# This program is free software: you can redistribute it and/or modify
# it under the terms of the GNU General Public License as published by
# the Free Software Foundation, either version 2 of the License, or
# (at your option) any later version.
#
# This program is distributed in the hope that it will be useful,
# but WITHOUT ANY WARRANTY; without even the implied warranty of
# MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
# GNU General Public License for more details.
#
# You should have received a copy of the GNU General Public License
# along with this program.  If not, see <http://www.gnu.org/licenses/>.
#

use Try::Tiny;
use Carp;

{
    package Koha::Squatting::Branch;
    use Squatting;

    our %CONFIG = (
        );
}

{
    package Koha::Squatting::Branch::Controllers;
    use Carp;
    use Try::Tiny;
    use Koha::Model::Branch;
    use Koha::Model::BranchSet;
    use C4::Auth ();

    our @returnable_types = (
        'application/json',
        'text/html'
        );

    sub _GetPreferredContentType {
        my ($accept_header) = @_; $accept_header //= '*/*';
        $accept_header =~ s/;.*$//;
        my @accepted_types = split(/,/, $accept_header);
        my @common = grep {$_ ~~ @returnable_types} @accepted_types;
        return $common[0];
    }

    sub _SetContentType {
        my $c = shift;
        my $type_preference = _GetPreferredContentType($c->env->{HTTP_ACCEPT});
        croak 'Unsupported content type' if !$type_preference;
        $c->headers->{'Content-Type'} = $type_preference;

        # only supporting JSON at this point
        $c->status = 415 unless ($type_preference ~~ 'application/json');
        return $type_preference;
    }

    sub BranchShow {
        my ($self, $branchcode) = @_;

        try {
            $self->v->{branch}
               = Koha::Model::Branch->new(branchcode => $branchcode)->load;
            $self->render('_rdb_obj', _SetContentType($self));
        }
        catch {
            if (/^No such Koha::/) {
                HTTP::Exception::404->throw;
            }
            else {
                carp $_;
                HTTP::Exception::500->throw;
            }
        };
    }

    sub BranchSetShow {
        my ($self) = @_;

        try {
            my $results
                = Koha::Model::BranchSet->new(limits => $self->input);
            $self->v->{branchset} = ($results) ? $results->branches : undef;
            $self->v->{inflate} = $self->input->{inflate} // 0;
            $self->render('_rdb_objset', _SetContentType($self));
        }
        catch {
            carp $_;
            HTTP::Exception::500->throw;
        };
    }

    our @C = (
        C( BranchShow => ['/branches/(\w+)'],
           get => \&BranchShow,
        ),
        C( BranchSetShow => ['/branches/'],
           get => \&BranchSetShow,
        ),
        );
}

{
    package Koha::Squatting::Branch::Views;
    use Rose::DB::Object::Helpers qw(as_tree as_json);
    use JSON qw(to_json);

    sub RenderRdbAsJson {
        my ($self, $v) = @_;
        return as_json($v->{branch});
    }

    sub RenderRdbSetAsJson {
        my ($self, $v) = @_;

        my @branchset;
        if (ref($v->{branchset}) ~~ 'ARRAY') {
            for my $r (@{$v->{branchset}}) {
                my $t = as_tree($r->db_obj);
                $t->{uri} = R('BranchShow', $t->{branchcode});
                push @branchset, $t;
            }
        }
        else {
               @branchset = ($v->{branchset});
        }
         return to_json(\@branchset);
    }

    our @V = (
        V('text/html',
          _ => sub {'Not yet supported'},
          403 => sub {'Permission denied'},
          404 => sub {'File not found'},
          deleted => sub {q()},
        ),
        V('application/json',
          _           => \&RenderRdbAsJson,
          _rdb_objset => \&RenderRdbSetAsJson,
        ),
        );
}

1;
