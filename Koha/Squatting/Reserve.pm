use Koha;
use Try::Tiny;
use Carp;

{
    package Koha::Squatting::Reserve;
    use Squatting;

    our %CONFIG = (
        );
}

{
    package Koha::Squatting::Reserve::Controllers;
    use Carp;
    use Try::Tiny;
    use HTTP::Exception;
    use Koha::Model::Reserve;
    use Koha::Model::ReserveSet;
    use C4::Auth ();

    our @returnable_types = (
        'text/html',
        'application/json'
        );

    sub _GetPreferredContentType {
        my ($accept_header) = @_;

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

    sub _CheckAuth {
        my ($self, $flags) = @_;

        my ($status, undef)
            = C4::Auth::check_cookie_auth($self->cookies->{CGISESSID}, $flags);

        unless ($status ~~ 'ok') {
            carp sprintf('Auth failed from %s accessing %s (cookie: %s)',
                         map {$self->env->{$_}} qw(REMOTE_ADDR REQUEST_URI HTTP_COOKIE)
                );
            HTTP::Exception::403->throw if ($status ne 'ok');
        }
        return 1;
    }

    sub ReserveShow {
        my ($self, $reserve_id) = @_;

        _CheckAuth($self, {reserveforothers => '*'});

        try {
            $self->v->{reserve}
                = Koha::Model::Reserve->new(reservenumber => $reserve_id)->load;
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

    sub ReserveSetShow {
        my ($self) = @_;

        _CheckAuth($self, {reserveforothers => '*'});

        try {
            my $results
                = Koha::Model::ReserveSet->new(limits => $self->input);
            $self->v->{reserveset} = ($results) ? $results->reserves : [];
            $self->v->{inflate} = $self->input->{inflate} // 0;
            $self->render('_rdb_objset', _SetContentType($self));
        }
        catch {
            carp $_;
            HTTP::Exception::500->throw;
        };
    }

    sub ReserveUpdate {
        my ($self, $reservenumber) = @_;

        _CheckAuth($self, {reserveforothers => 'edit_holds'});

        my $input = $self->input;
        my $r = Koha::Model::Reserve->new(reservenumber => $reservenumber);
        $r->load;

        $input->{priority} //= $r->priority;
        $input->{branchcode} //= $r->branchcode;

        if ($r->found ~~ 'S' && !$input->{is_suspended}) {
            $r->unsuspend();
        }
        elsif (!($r->found ~~ 'S') && $input->{is_suspended}) {
            $r->suspend($input->{resume_date});
        }

        $r->priority($input->{priority});
        $r->branchcode($input->{branchcode});
        $r->save;

        return ReserveShow($self, $reservenumber);
    }

    sub ReserveCreate {
        my ($self) = @_;

        _CheckAuth($self, {reserveforothers => 'add_holds'});

        my $input = $self->input;
        my $r = Koha::Model::Reserve->new();
        $r->borrowernumber($input->{borrowernumber});
        $r->branchcode($input->{branchcode});
        $r->biblionumber($input->{biblionumber});
        try {
            $r->save();
        }
        catch {
            HTTP::Exception::401->throw;
        };

        return ReserveShow($self, $r->reservenumber);
    }

    sub ReserveCancel {
        my ($self, $reservenumber) = @_;

        _CheckAuth($self, {reserveforothers => 'delete_holds'});

        try {
            my $r = Koha::Model::Reserve->new(reservenumber => $reservenumber);
            $r->delete;
            $self->status = 204;
            $self->render('deleted');
        }
        catch {
            if (/^Unable to find reserve/) {
                HTTP::Exception::404->throw;
            }
            else {
                carp $_;
                HTTP::Exception::500->throw;
            }
        };
    }

    our @C = (
        C( ReserveSingle => ['/reserves/(\d+)'],
           get => \&ReserveShow,
           post => \&ReserveUpdate,
           delete => \&ReserveCancel,
        ),
        C( ReserveSet => ['/reserves/'],
           get => \&ReserveSetShow,
           post => \&ReserveCreate,
        ),
        );
}

{
    package Koha::Squatting::Reserve::Views;
    use Rose::DB::Object::Helpers qw(as_tree as_json);
    use JSON qw(to_json);

    sub RenderRdbAsJson {
        my ($self, $v) = @_;
        as_json($v->{reserve});
    }

    sub RenderRdbSetAsJson {
        my ($self, $v) = @_;

        my @reserveset;
        if ($v->{inflate}) {
            for my $r (@{$v->{reserveset}}) {
                my $t = as_tree($r->db_obj);
                $t->{title} = $r->biblio->title;
                $t->{author} = $r->biblio->author;
                $t->{borrowername} = sprintf('%s, %s',
                                             $r->borrower->surname,
                                             $r->borrower->firstname);
                $t->{borrowercard} = $r->borrower->cardnumber;
                $t->{branchname} =  $r->branchcode; #for now... no FK in db
                $t->{itembarcode} = ($r->item) ? $r->item->barcode : undef;
                $t->{uri} = R('ReserveSingle', $t->{reservenumber});
                push @reserveset, $t;
            }
        }
        else {
            @reserveset = map {R('ReserveSingle', $_->reservenumber)} @{$v->{reserveset}};
        }
        to_json(\@reserveset);
    }

    our @V = (
        V('text/html',
          _ => sub {'Not yet supported'},
          deleted => sub {q()},
        ),
        V('application/json',
          _ => \&RenderRdbAsJson,
          _rdb_objset => \&RenderRdbSetAsJson,
        ),
        );
}

1;
