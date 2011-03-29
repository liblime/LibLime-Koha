#!/usr/bin/env perl

# Copyright 2000-2009 LibLime
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


=head1 courses.pl

Script to manage a courses

=cut

use strict;

use CGI;
use C4::Context;
use C4::Auth;
use C4::Output;
use C4::Members;
use C4::Dates qw(format_date_in_iso);
use C4::Courses qw(GetCourse GetCourses GetCourseReserves);
use Date::Calc qw(Today Date_to_Days);
use C4::Branch qw(GetBranchName GetBranchesLoop);
use C4::Koha;
use C4::Items;

my $query = CGI->new();
my $debug;

my $op = $query->param("op");
my $limit = $query->param("limit");
my $course_id = $query->param("course_id");
my $departments = GetAuthorisedValues('DEPARTMENT');
my $terms = GetAuthorisedValues('TERM');
my ($template, $loggedinuser, $cookie)
    = get_template_and_user(
        {template_name => "opac-coursereserves.tmpl",
           query => $query,
           type => "opac",
           authnotrequired => 1,
           debug => ($debug) ? 1 : 0,
       });

# Courses CRUD
# Load the course from the course_id if loading the update form
my $course_hash = GetCourse($course_id);

if ($op and $op eq 'view_course_reserves' ) {
    my $course = GetCourse($course_id);

    $template->param(
        course_id           => $course->{"course_id"},
        department          => $course->{"department"},
        course_number       => $course->{"course_number"},
        section             => $course->{"section"},
        course_name         => $course->{"course_name"},
        term                => $course->{"term"},
        staff_note          => $course->{"staff_note"},
        public_note         => $course->{"public_note"},
        students_count      => $course->{"students_count"},
        course_status       => $course->{"course_status"},
	);

    my $course_reserves = GetCourseReserves($course_id);
    if (defined $course_reserves) {
	my @cr = sort {$a->{title} cmp $b->{title}} @$course_reserves;
	my $branches = GetBranchesLoop();
	my $ccodes = GetAuthorisedValues('CCODE');
	my $locations = GetAuthorisedValues('LOC');
	my @itemtypes;
	my $koha_itemtypes = GetItemTypes();
	for my $itemtype ( sort {$koha_itemtypes->{$a}->{'description'} cmp $koha_itemtypes->{$b}->{'description'} } keys %$koha_itemtypes ) {
	    push @itemtypes, { code => $itemtype, description => $koha_itemtypes->{$itemtype}->{'description'} };
	}

	$template->param(
	    COURSE_RESERVES => \@cr,
	    ITEMTYPES => \@itemtypes,
	    LOCATIONS => $locations,
	    CCODES => $ccodes,
	    BRANCHES => $branches,
	    );
    }
}
else {
    my $courses = GetCourses($limit);
	#for my $course (@$courses) {
	#}
    $template->param(COURSES => $courses);
}
if ($op and $op eq 'update') {
    $template->param(
    course_id           => $course_hash->{"course_id"},
    department          => $course_hash->{"department"},
    course_number       => $course_hash->{"course_number"},
    section             => $course_hash->{"section"},
    course_name         => $course_hash->{"course_name"},
    term                => $course_hash->{"term"},
    instructors         => $course_hash->{"instructors"},
    staff_note          => $course_hash->{"staff_note"},
    public_note         => $course_hash->{"public_note"},
    students_count      => $course_hash->{"students_count"},
    course_status       => $course_hash->{"course_status"},
    );
}

$template->param(
    instructors         => $course_hash->{"instructors"},
    op => $op,
    $op => 1,
    $course_hash->{"course_status"} => 1,
    TERMS => $terms,
    DEPARTMENTS => $departments
);
output_html_with_http_headers $query, $cookie, $template->output;
