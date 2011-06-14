#!/usr/bin/env perl

# script to edit a member's flags
# Written by Steve Tonnesen
# July 26, 2002 (my birthday!)

use strict;
use warnings;

use CGI;
use C4::Output;
use C4::Auth qw(:DEFAULT :EditPermissions);
use C4::Context;
use C4::Members;
use C4::Branch;
use C4::Output;

our $input = CGI->new();

my $flagsrequired = { permissions => 1 };
our ( $template, $loggedinuser, $cookie ) = get_template_and_user(
    {   template_name   => 'members/member-flags.tmpl',
        query           => $input,
        type            => 'intranet',
        authnotrequired => 0,
        flagsrequired   => $flagsrequired,
        debug           => 1,
    }
);

my $member        = $input->param('member');
our $bor           = GetMemberDetails( $member, q{} );
if ( $bor->{'category_type'} eq 'S' ) {
    $flagsrequired->{'staffaccess'} = 1;
}
( $template, $loggedinuser, $cookie ) = get_template_and_user(
    {   template_name   => 'members/member-flags.tmpl',
        query           => $input,
        type            => 'intranet',
        authnotrequired => 0,
        flagsrequired   => $flagsrequired,
        debug           => 1,
    }
);

my %member2;
$member2{'borrowernumber'} = $member;

if ( $input->param('newflags') ) {
    update_and_redirect($member);
} else {
    prepare_for_output();

    output_html_with_http_headers $input, $cookie, $template->output;

}

sub prepare_for_output {

    my $flags       = $bor->{flags};
    my $accessflags = $bor->{authflags};
    my $dbh         = C4::Context->dbh();
    my $all_perms   = get_all_subpermissions();
    my $user_perms  = get_user_subpermissions( $bor->{userid} );
    my @loop;

    my $user_flags = $dbh->selectall_arrayref(
        'SELECT bit,flag,flagdesc FROM userflags ORDER BY bit',
        { Slice => {} } );
    for my $uf ( @{$user_flags} ) {
        my $checked = 0;
        if ( $accessflags->{ $uf->{flag} } ) {
            $checked = 1;
        }

        my $row = {
            bit      => $uf->{bit},
            flag     => $uf->{flag},
            checked  => $checked,
            flagdesc => $uf->{flagdesc},
        };

        if ( C4::Context->preference('GranularPermissions') ) {
            add_subpermissions_to_row( $row, $uf->{flag}, $all_perms,
                $user_perms );
        }
        push @loop, $row;
    }

    if ( $bor->{'category_type'} eq 'C' ) {
        my ( $catcodes, $labels ) =
          GetborCatFromCatType( 'A', 'WHERE category_type = ?' );
        if ( @{$catcodes} ) {
            if ( scalar @{$catcodes} == 1 ) {
                $template->param( 'catcode' => $catcodes->[0] );
            } else {
                $template->param( 'CATCODE_MULTI' => 1 );
            }
        }
    }

    if ( $bor->{'category_type'} eq 'A' ) {
        $template->param( adultborrower => 1 );
    }
    my ( $picture, $dberror ) = GetPatronImage( $bor->{'cardnumber'} );
    if ($picture) {
        $template->param( picture => 1 );
    }

    $template->param(
        borrowernumber => $bor->{'borrowernumber'},
        cardnumber     => $bor->{'cardnumber'},
        surname        => $bor->{'surname'},
        firstname      => $bor->{'firstname'},
        categorycode   => $bor->{'categorycode'},
        category_type  => $bor->{'category_type'},
        categoryname   => $bor->{'description'},
        address        => $bor->{'address'},
        address2       => $bor->{'address2'},
        city           => $bor->{'city'},
        zipcode        => $bor->{'zipcode'},
	country	       => $bor->{'country'},
        phone          => $bor->{'phone'},
        email          => $bor->{'email'},
        branchcode     => $bor->{'branchcode'},
        branchname     => GetBranchName( $bor->{'branchcode'} ),
	loop	=> \@loop,
        is_child       => ( $bor->{'category_type'} eq 'C' ),
    );
    return;
}

sub get_set_permissions {
    my @set_permissions = @_;
    my $all_module      = {};
    my $sub_perms       = {};
    for (@set_permissions) {
        if (/^([^\:]+):([^\:]+)/) {
            push @{ $sub_perms->{$1} }, $2;
        } else {
            $all_module->{$_} = 1;
        }
    }

    return $all_module, $sub_perms;
}

sub update_and_redirect {
    my $member = shift;
    my $query = "
      INSERT INTO borrower_edits
        (borrowernumber,staffnumber,field,before_value,after_value)
      VALUES (?,?,?,?,?)";

    my ( $all_module_perms, $sub_perms ) =
      get_set_permissions( $input->param('flag') );

    my $dbh = C4::Context->dbh();
    my ($sth,$sth2);

    # examine existing sub permissions before deletion for logging purposes
    $sth = $dbh->prepare(
      'SELECT * FROM user_permissions WHERE borrowernumber = ?');
    $sth->execute($member);
    my $old_user_subpermissions = $sth->fetchall_arrayref({});

    # construct flags
    my $accessflags = $bor->{authflags};
    my $field;
    my $all_subperms = get_all_subpermissions();
    my $module_flags = 0;
    my $userflags =
      $dbh->selectall_arrayref( 'SELECT bit,flag FROM userflags ORDER BY bit',
        { Slice => {} } );
    for my $uf ( @{$userflags} ) {
        if ( exists $all_module_perms->{ $uf->{flag} } ) {
            $module_flags += 2**$uf->{bit};
        }
        if (defined($accessflags->{$uf->{flag}}) && !defined($all_module_perms->{$uf->{flag}})) {
          $sth2 = $dbh->prepare($query);
          $field = $uf->{flag} . " permission";
          $sth2->execute($member,$loggedinuser,$field,'ON','OFF');
          foreach my $sub_perm ( keys %{$all_subperms->{$uf->{flag}}} ) {
            push @$old_user_subpermissions,  { borrowernumber => $member,
                                               module_bit     => $uf->{bit},
                                               code           => $sub_perm };
          }
        }
        if (!defined($accessflags->{$uf->{flag}}) && defined($all_module_perms->{$uf->{flag}})) {
          $sth2 = $dbh->prepare($query);
          $field = $uf->{flag} . " permission";
          $sth2->execute($member,$loggedinuser,$field,'OFF','ON');
        }
    }

    $sth =
      $dbh->prepare('UPDATE borrowers SET flags=? WHERE borrowernumber=?');
    $sth->execute( $module_flags, $member );

    if ( C4::Context->preference('GranularPermissions') ) {

        my %flags;
        $sth2 = $dbh->prepare(
            'SELECT bit,flag FROM userflags');
        $sth2->execute();
        while (my $userflag = $sth2->fetchrow_hashref) {
          $flags{$userflag->{flag}} = $userflag->{bit};
        }

        # remove existing sub permissions
        $sth = $dbh->prepare(
            'DELETE FROM user_permissions WHERE borrowernumber = ?');
        $sth->execute($member);

        # add new user_permissions
        my $stmt =
            'INSERT INTO user_permissions (borrowernumber, module_bit, code)'
          . ' SELECT ?, bit, ? FROM userflags WHERE flag = ?';
        $sth = $dbh->prepare($stmt);
        foreach my $module ( keys %{$sub_perms} ) {
            next if exists $all_module_perms->{$module};
            foreach my $sub_perm ( @{ $sub_perms->{$module} } ) {
                $sth->execute( $member, $sub_perm, $module );
            }
            foreach my $prev_perm (@$old_user_subpermissions) {
              my $found = 0;
              next if ($prev_perm->{module_bit} ne $flags{$module});
              foreach my $sub_perm ( @{ $sub_perms->{$module} } ) {
                if ($prev_perm->{code} eq $sub_perm) {
                  $found = 1;
                  last;
                }
              }
              if (!$found) {
                $sth2 = $dbh->prepare($query);
                $field = $prev_perm->{code} . " permission";
                $sth2->execute($member,$loggedinuser,$field,'ON','OFF');
              }
            }
            foreach my $sub_perm ( @{ $sub_perms->{$module} } ) {
              my $found = 0;
              foreach my $prev_perm (@$old_user_subpermissions) {
                next if ($prev_perm->{module_bit} ne $flags{$module});
                if ($prev_perm->{code} eq $sub_perm) {
                  $found = 1;
                  last;
                }
              }
              if (!$found) {
                $sth2 = $dbh->prepare($query);
                $field = $sub_perm . " permission";
                $sth2->execute($member,$loggedinuser,$field,'OFF','ON');
              }
            }
        }
    }

    return
      print $input->redirect(
        "/cgi-bin/koha/members/moremember.pl?borrowernumber=$member");
}

sub add_subpermissions_to_row {
    my ( $row, $flag, $all_perms, $user_perms ) = @_;

    my $sub_perm_loop;
    my $expand_parent = 0;
    if ( $row->{checked} ) {
        if ( exists $all_perms->{$flag} ) {
            $expand_parent = 1;
            foreach my $sub_perm ( sort keys %{ $all_perms->{$flag} } ) {
                push @{$sub_perm_loop},
                  { id          => "${flag}_$sub_perm",
                    perm        => "$flag:$sub_perm",
                    code        => $sub_perm,
                    description => $all_perms->{$flag}->{$sub_perm},
                    checked     => 1
                  };
            }
        }
    } else {
        if ( exists $user_perms->{$flag} ) {
            $expand_parent = 1;

            # put selected ones first
            foreach my $sub_perm ( sort keys %{ $user_perms->{$flag} } ) {
                push @{$sub_perm_loop},
                  { id          => "${flag}_$sub_perm",
                    perm        => "$flag:$sub_perm",
                    code        => $sub_perm,
                    description => $all_perms->{$flag}->{$sub_perm},
                    checked     => 1,
                  };
            }
        }

        # then ones not selected
        if ( exists $all_perms->{$flag} ) {
            foreach my $sub_perm ( sort keys %{ $all_perms->{$flag} } ) {
                if ( !exists $user_perms->{$flag}->{$sub_perm} ) {
                    push @{$sub_perm_loop},
                      { id          => "${flag}_$sub_perm",
                        perm        => "$flag:$sub_perm",
                        code        => $sub_perm,
                        description => $all_perms->{$flag}->{$sub_perm},
                        checked     => 0,
                      };
                }
            }
        }
    }

    $row->{expand} = $expand_parent;
    if ($sub_perm_loop) {
        $row->{sub_perm_loop} = $sub_perm_loop;
    }

    return;
}

