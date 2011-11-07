#!/usr/bin/env perl

# Script for handling import of MARC data into Koha db
#   and Z39.50 lookups

# Koha library project  www.koha.org

# Licensed under the GPL

# Copyright 2000-2002 Katipo Communications
#
# This file is part of Koha.
#
# Koha is free software; you can redistribute it and/or modify it under the
# terms of the GNU General Public License as published by the Free Software
# Foundation; either version 2 of the License, or (at your op) any later
# version.
#
# Koha is distributed in the hope that it will be useful, but WITHOUT ANY
# WARRANTY; without even the implied warranty of MERCHANTABILITY or FITNESS FOR
# A PARTICULAR PURPOSE.  See the GNU General Public License for more details.
#
# You should have received a copy of the GNU General Public License along with
# Koha; if not, write to the Free Software Foundation, Inc., 59 Temple Place,
# Suite 330, Boston, MA  02111-1307 USA

use strict;

# standard or CPAN modules used
use CGI;
use CGI::Cookie;
use MARC::File::USMARC;

# Koha modules used
use Koha;
use C4::Context;
use C4::Auth;
use C4::Output;
use C4::Biblio;
use C4::ImportBatch;
use C4::Matcher;
use C4::UploadedFile;
use C4::BackgroundJob;
use C4::Form::AddItem;
use C4::Dates;

my $input = new CGI;
my $dbh = C4::Context->dbh;
$dbh->{AutoCommit} = 0;

my $fileID=$input->param('uploadedfileid');
my $runinbackground = $input->param('runinbackground');
my $completedJobID = $input->param('completedJobID');
my $matcher_id = $input->param('matcher');
my $overlay_action = $input->param('overlay_action');
my $nomatch_action = $input->param('nomatch_action');
my $parse_items = $input->param('parse_items');
my $item_action = $input->param('item_action');
my $comments = $input->param('comments');
my $syntax = $input->param('syntax');
my $profile = $input->param('profile');
my $new_profile_name = $input->param('new_profile_name');
my $retrieve = $input->param('retrieve') || '';

my $template_name = "tools/stage-marc-import.tmpl";
if ( $retrieve eq 'profile-items' ) {
    $template_name = 'tools/pieces/import-profile-items.tmpl';
} elsif ( $retrieve eq 'profile-actions' ) {
    $template_name = 'tools/pieces/import-profile-actions.tmpl';
}

my ($template, $loggedinuser, $cookie)
	= get_template_and_user({template_name => $template_name,
					query => $input,
					type => "intranet",
					authnotrequired => 1,
					flagsrequired => {tools => 'stage_marc_import'},
					debug => 1,
					});

my $tagslib = &GetMarcStructure(1, ''); # Assuming default framework

if ( $retrieve ) {
    if ( $retrieve eq 'profile-items' ) {
        $template->param( items => [ map {
            my $item_index = int(rand(10000000));
            +{ item_index => $item_index, item => C4::Form::AddItem::get_form_values( $tagslib, $item_index, {
                item => $_,
                omit => [ 'items.barcode' ],
                allow_repeatable => 0,
            } ) };
        } GetImportProfileItems( $profile ) ] );
    } elsif ( $retrieve eq 'profile-actions' ) {
        $template->param( actions => [ GetImportProfileSubfieldActions( $profile ) ] );
    }
    output_html_with_http_headers $input, $cookie, $template->output;
    exit;
}

$template->param(SCRIPT_NAME => $ENV{'SCRIPT_NAME'},
						uploadmarc => $fileID);

my %cookies = parse CGI::Cookie($cookie);
my $sessionID = $cookies{'CGISESSID'}->value;
if ($completedJobID) {
    my $job = C4::BackgroundJob->fetch($sessionID, $completedJobID);
    my $results = $job->results();
    $template->param(map { $_ => $results->{$_} } keys %{ $results });
} elsif ($fileID) {
    my $uploaded_file = C4::UploadedFile->fetch($sessionID, $fileID);
    my $fh = $uploaded_file->fh();
	my $marcrecord='';
    $/ = "\035";
	while (<$fh>) {
        s/^\s+//;
        s/\s+$//;
		$marcrecord.=$_;
	}

    my $filename = $uploaded_file->name();
    my $job = undef;
    my $staging_callback = sub { };
    my $matching_callback = sub { };

    my @additional_items;
    my @subfield_actions;

    my @added_items = C4::Form::AddItem::get_all_items($input, '');

    if ( $profile ) {
        if ( $input->param( 'include_items_from_profile' ) && !@added_items) {
            push @additional_items, GetImportProfileItems( $profile );
        }
        if ( $input->param( 'include_actions_from_profile' ) ) {
            push @subfield_actions, GetImportProfileSubfieldActions( $profile );
        }
    }

     push @additional_items, @added_items;
#    push @additional_items, C4::Form::AddItem::get_all_items( $input, '' );
    push @subfield_actions, get_subfield_actions( $input );

	if ( $new_profile_name ) {
		$new_profile_name =~ s/^\s+|\s+$//g;
		AddImportProfile( $new_profile_name, $matcher_id, undef, $overlay_action, $nomatch_action, $parse_items, $item_action, \@additional_items, \@subfield_actions );
	}

    if ($runinbackground) {
        my $job_size = () = $marcrecord =~ /\035/g;
        # if we're matching, job size is doubled
        $job_size *= 2 if ($matcher_id ne "");
        $job = C4::BackgroundJob->new($sessionID, $filename, $ENV{'SCRIPT_NAME'}, $job_size);
        my $jobID = $job->id();

        # fork off
        if (my $pid = fork) {
            # parent
            # return job ID as JSON
            
            # prevent parent exiting from
            # destroying the kid's database handle
            # FIXME: according to DBI doc, this may not work for Oracle
            $dbh->{InactiveDestroy}  = 1;

            my $reply = CGI->new("");
            print $reply->header(-type => 'text/html');
            print "{ jobID: '$jobID' }";
            exit 0;
        } elsif (defined $pid) {
            # child
            # close STDOUT to signal to Apache that
            # we're now running in the background
            close STDOUT;
            close STDERR;
        } else {
            # fork failed, so exit immediately
            warn "fork failed while attempting to run $ENV{'SCRIPT_NAME'} as a background job";
            exit 0;
        }

        # if we get here, we're a child that has detached
        # itself from Apache
       # $staging_callback = staging_progress_callback($job, $dbh);
       # $matching_callback = matching_progress_callback($job, $dbh);

    }

    # FIXME branch code
    my ($batch_id, $num_valid, $num_items, @import_errors) = BatchStageMarcRecords($syntax, $marcrecord, $filename, 
                                                                                   $comments, '', $parse_items, 0,
                                                                                   \@additional_items, \@subfield_actions);
                                                                               #    50, staging_progress_callback($job, $dbh));
    $dbh->commit();
    my $num_with_matches = 0;
    my $checked_matches = 0;
    my $matcher_failed = 0;
    my $matcher_code = "";
    if ($matcher_id ne "") {
        my $matcher = C4::Matcher->fetch($matcher_id);
        if (defined $matcher) {
            $checked_matches = 1;
            $matcher_code = $matcher->code();
            #$num_with_matches = BatchFindBibDuplicates($batch_id, $matcher, 
            #                                           10, 50, matching_progress_callback($job, $dbh));
            $num_with_matches = BatchFindBibDuplicates($batch_id, $matcher); 
            SetImportBatchMatcher($batch_id, $matcher_id);
            SetImportBatchOverlayAction($batch_id, $overlay_action);
            SetImportBatchNoMatchAction($batch_id, $nomatch_action);
            if ( @additional_items) {
               SetImportBatchItemAction($batch_id, 'always_add');
            } else {
               SetImportBatchItemAction($batch_id, $item_action);
            }
            $dbh->commit();
        } else {
            $matcher_failed = 1;
        }
    }

    my $results = {
	    staged => $num_valid,
 	    matched => $num_with_matches,
        num_items => $num_items,
        import_errors => scalar(@import_errors),
        total => $num_valid + scalar(@import_errors),
        checked_matches => $checked_matches,
        matcher_failed => $matcher_failed,
        matcher_code => $matcher_code,
        import_batch_id => $batch_id
    };

	$results->{'saved_profile'} = $new_profile_name if ($new_profile_name);

    if ($runinbackground) {
        $job->finish($results);
    } else {
	    $template->param($results);
	}

} else {
    # initial form
    if (C4::Context->preference("marcflavour") eq "UNIMARC") {
        $template->param("UNIMARC" => 1);
    }
    my @matchers = C4::Matcher::GetMatcherList();
    $template->param(
		available_matchers => \@matchers,
		available_profiles => GetImportProfileLoop(),
        item => C4::Form::AddItem::get_form_values( $tagslib, 0, { omit => [ 'items.barcode' ], allow_repeatable => 0 } ),
        today_iso => C4::Dates->today( 'iso' ),
	);
}

output_html_with_http_headers $input, $cookie, $template->output;

exit 0;

sub staging_progress_callback {
    my $job = shift;
    my $dbh = shift;
    return sub {
        my $progress = shift;
        $job->progress($progress);
        $dbh->commit();
    }
}

sub matching_progress_callback {
    my $job = shift;
    my $dbh = shift;
    my $start_progress = $job->progress();
    return sub {
        my $progress = shift;
        $job->progress($start_progress + $progress);
        $dbh->commit();
    }
}

sub get_subfield_actions {
    my ( $input ) = @_;

    my @types = $input->param( 'action_type' );
    my @tags = $input->param( 'action_tag' );
    my @subfields = $input->param( 'action_subfield' );
    my @contents = $input->param( 'action_contents' );
    my @results;

    foreach my $i ( 0..$#types ) {
		next unless ( $tags[$i] );
        push @results, {
            action => $types[$i],
            tag => $tags[$i],
            subfield => $subfields[$i],
            contents => $contents[$i],
        };
    }

    return @results;
}
