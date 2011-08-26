package Koha::Plack::Util;

use Koha;

sub GetCanonicalHostname {
    my $env = shift;

    my $hostname
        =  $env->{HTTP_X_FORWARDED_HOST}
        // $env->{HTTP_X_FORWARDED_SERVER}
        // $env->{HTTP_HOST}
        // $env->{SERVER_NAME}
        // 'koha-opac.default';
    $hostname = (split qr{,}, $hostname)[0];
    $hostname =~ s/:.*//;

    return $hostname;
}

sub IsStaff {
    my $hostname = GetCanonicalHostname(shift);
    return $hostname =~ /-staff/;
}

sub RedirectRootAndOpac {
    my $env = shift;
    my $is_staff = shift // \&IsStaff;

    return 302 if ($is_staff->($env) && s{^/$}{/cgi-bin/koha/mainpage.pl});
    return 302 if (!$is_staff->($env) && s{^/$}{/cgi-bin/koha/opac-main.pl});
    if (!$is_staff->($env)) { s{^/cgi-bin/koha/}{/cgi-bin/koha/opac/}}
    return;
}

# This needs to be turned into a proper middleware package
sub PrefixFhOutput {
    my $app = shift;

    {
        package Koha::Plack::Util::PrefixFhOutput;
        our $name = '';
        our $fh;

        sub TIEHANDLE {
            open my $old_err, '>&', $fh;
            my $self = {fh => $old_err};
            bless $self, shift;
        }

        sub PRINT {
            my $self = shift;
            return if not scalar @_;
            my $format = ($name) ? qq{[$name] } . shift @_ : shift @_;
            print {$self->{fh}} sprintf $format, @_;
        }

        sub PRINTF { PRINT @_ }
    }

    return sub {
        my $env = shift;

        local $Koha::Plack::Util::PrefixFhOutput::name = Koha::Plack::Util::GetCanonicalHostname($env);
        local $Koha::Plack::Util::PrefixFhOutput::fh = $env->{'psgi.errors'};

        tie(*{$env->{'psgi.errors'}}, 'Koha::Plack::Util::PrefixFhOutput');

        return $app->($env);
    };
}

1;
