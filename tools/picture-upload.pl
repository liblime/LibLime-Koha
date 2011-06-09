#!/usr/bin/env perl
#
# picture-upload.p. - Script for handling uploading of both single and bulk 
# patronimages and importing them into the database.
#
# AUTHORS
# - Original contributor(s) undocumented.
# - 02 Feb 2011 hQ PTFS/LibLime
#   * Refactored to work under strict.
#   * Removed debug messages that slow down processing.
#   * Added search cardnumber substring with multibranch prefix expansion.
# - Chris Nighswonger, cnighswonger <at> foundations <dot> edu
#   * Database storage, single patronimage upload option, and extensive error 
#     trapping contributed.
#   * Image scaling/resizing.
#
# FIXME: Other parts of this code could be optimized as well, I think. Perhaps
# the file upload could be done with YUI's upload
#       coded. -fbcit
#
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
#

use strict;
use File::Temp;
use File::Copy;
use CGI;
use GD;
use Koha;
use C4::Context;
use C4::Auth;
use C4::Output;
use C4::Members;

my $input  = new CGI;
my ($template, $loggedinuser, $cookie) = get_template_and_user({
   template_name  => 'tools/picture-upload.tmpl',
   query          => $input,
   type           => 'intranet',
   authnotrequired=> 0,
   flagsrequired  => { tools => 'batch_upload_patron_images'},
   debug          => 0,
});

my $filetype            = $input->param('filetype');
my $cardnumber          = $input->param('cardnumber');
my $uploadfilename      = $input->param('uploadfile');
my $uploadfile          = $input->upload('uploadfile');
my $borrowernumber      = $input->param('borrowernumber');
my $op                  = $input->param('op');

my(%errors,@counts,%filerrors,@filerrors,$filename);
if ($op eq 'FindBorrower') {
   my $borrowers = C4::Members::SearchMember($cardnumber) // [];
   $template->param(
      borrowers   => $borrowers,
   );
}
elsif (($op eq 'Upload') && $uploadfile) {
   # Case is important in these operational values as the 
   # template must use case to be visually pleasing!
   _process_upload();
} 
elsif (($op eq 'Upload') && !$uploadfile) {
   $template->param(
      cardnumber => $cardnumber,
      filetype   => $filetype
   );
}
elsif ($op eq 'Delete') {
    #my $dberror = RmPatronImage($cardnumber);
    C4::Members::RmPatronImage($cardnumber);
}

if (%errors) {
   $template->param( ERRORS => [ \%errors ] );
}
elsif ($borrowernumber) {
    print $input->redirect('/cgi-bin/koha/members/'
    . "moremember.pl?borrowernumber=$borrowernumber");
    exit;
}
else {
   my $bor = C4::Members::GetMemberDetails(undef,$cardnumber,undef);
   $template->param(borrowernumber=>$$bor{borrowernumber});
}

output_html_with_http_headers $input, $cookie, $template->output;
exit;

##########################################################################
sub _process_upload
{
   my $dirname      = File::Temp::tempdir( CLEANUP => 1);
   my $filesuffix   = $1 if $uploadfilename =~ m/(\..+)$/i;
   my($tfh,$tmpfile) = File::Temp::tempfile( SUFFIX => $filesuffix, UNLINK => 1 );

   $errors{'NOTZIP'}      = 1 if ( $uploadfilename !~ /\.zip$/i && $filetype =~ m/zip/i );
   $errors{'NOWRITETEMP'} = 1 unless ( -w $dirname );
   $errors{'EMPTYUPLOAD'} = 1 unless ( length( $uploadfile ) > 0 );
   return if %errors;
	 
   while (<$uploadfile>) {
	   print $tfh $_;
   }
   close $tfh;
   
   my($handled,$total,$results);
   if ($filetype eq 'zip') {
      ## FIXME: use a pure Perl technique instead of system()
      unless (system("unzip $tmpfile -d $dirname") == 0) {
         $errors{'UZIPFAIL'} = $uploadfilename;
         return;
      }
      my(@directories,$dir);
      push @directories, "$dirname";
      foreach my $recursive_dir ( @directories ) {
         opendir $dir, $recursive_dir;
         while ( my $entry = readdir $dir ) {
	         push @directories, "$recursive_dir/$entry" if ( -d "$recursive_dir/$entry" and $entry !~ /^\./ );
         }   
         closedir $dir;
      }       
      foreach $dir ( @directories ) {
         $results = _handle_dir( 
            dir    => $dir, 
            suffix => $filesuffix,
            tmpfile=> $tmpfile
         );
         $handled++ if $results == 1;
      }
      $total = scalar @directories;
   } 
   else {
      _handle_dir( 
         dir     => $dirname, 
         suffix  => $filesuffix,
         tmpfile => $tmpfile
      );
      return if %errors;
      $handled = 1;
      $total = 1;
   }
  
   my $filecount;
   map {$filecount += $_->{count}} @counts;
   $template->param(
      TOTAL    => $total,
		HANDLED  => $handled,
      COUNTS   => \@counts,
      TCOUNTS  => ($filecount > 0 ? $filecount : undef),
   );
   $template->param( borrowernumber => $borrowernumber ) if $borrowernumber;
   return;
}

sub _handle_dir 
{
   my %g = @_; ## dir, suffix, tmpfile
   my($source,%cnts);
   if ($g{suffix} =~ m/zip/i) {     # If we were sent a zip file, process any included data/idlink.txt files 
      my ( $file, $filename, $cardnumber );
      opendir DIR, $g{dir};
      while ( my $filename = readdir DIR ) {
         $file = "$g{dir}/$filename" if ($filename =~ m/datalink\.txt/i || $filename =~ m/idlink\.txt/i);
      }
      open FILE, "<$file" || die "can't open-read $file: $!\n";
      while (my $line = <FILE>) {
	      chomp $line;
	      my $delim = ($line =~ /\t/) ? "\t" : ($line =~ /,/) ? "," : "";
         unless ( $delim eq ',' || $delim eq "\t" ) {
            $errors{'DELERR'} = 1; 
            return;
         }
	      ($cardnumber, $filename) = split $delim, $line;
	      $cardnumber =~ s/[\"\r\n]//g;  # remove offensive characters
	      $filename   =~ s/[\"\r\n\s]//g;
         $source     = "$g{dir}/$filename";
         %cnts       = _handle_file($cardnumber, $source, %cnts);
      }
      close FILE;
      closedir DIR;
   } 
   else {
      $source = $g{tmpfile};
      %cnts   = _handle_file($cardnumber, $source, %cnts);
   }
   push @counts, \%cnts;
   return 1;
}

sub _handle_file {
    my ($cardnumber, $source, %count) = @_;
    $count{filenames} = () if !$count{filenames};
    $count{source} = $source if !$count{source};
    if ($cardnumber && $source) {     # Now process any imagefiles
        if ($filetype eq 'image') {
            $filename = $uploadfilename;
        } else {
            $filename = $1 if ($source =~ /\/([^\/]+)$/);
        }
        my $size = (stat($source))[7];
            # This check is necessary even with image resizing to avoid 
            # possible security/performance issues...
            if ($size > 100000) { 
                $filerrors{'OVRSIZ'} = 1;
                push my @filerrors, \%filerrors;
                push @{ $count{filenames} }, { 
                  filerrors   => \@filerrors, 
                  source      => $filename, 
                  cardnumber  => $cardnumber 
                };
                $template->param( ERRORS => 1 );
                return %count;    # this one is fatal so bail here...
            }
        my ($srcimage, $image);
        if (open (IMG, "$source")) {
            $srcimage = GD::Image->new(*IMG);
            close (IMG);
			if (defined $srcimage) {
            my $imgfile;
				my $mimetype = 'image/jpeg';	# GD autodetects three basic image formats: PNG, JPEG, XPM; we will convert all to JPEG...
				# Check the pixel size of the image we are about to import...
				my ($width, $height) = $srcimage->getBounds();
				if ($width > 140 || $height > 200) {    # MAX pixel dims are 140 X 200...
					my $percent_reduce;    # Percent we will reduce the image dimensions by...
					if ($width > 140) {
						$percent_reduce = sprintf("%.5f",(140/$width));    # If the width is oversize, scale based on width overage...
					} else {
						$percent_reduce = sprintf("%.5f",(200/$height));    # otherwise scale based on height overage.
					}
					my $width_reduce = sprintf("%.0f", ($width * $percent_reduce));
					my $height_reduce = sprintf("%.0f", ($height * $percent_reduce));
					$image = GD::Image->new($width_reduce, $height_reduce, 1); #'1' creates true color image...
					$image->copyResampled($srcimage,0,0,0,0,$width_reduce,$height_reduce,$width,$height);
					$imgfile = $image->jpeg(100);
					undef $image;
					undef $srcimage;    # This object can get big...
				} else {
					$image = $srcimage;
					$imgfile = $image->jpeg();
					undef $image;
					undef $srcimage;    # This object can get big...
				}
				my $dberror = C4::Members::PutPatronImage(
               cardnumber  => $cardnumber,
               mimetype    => $mimetype,
               imgfile     => $imgfile,
            ) if $mimetype;
				if ( !$dberror && $mimetype ) { # Errors from here on are fatal only to the import 
            # of a particular image, so don't bail, just note the error and keep going
					$count{count}++;
					push @{ $count{filenames} }, { source => $filename, cardnumber => $cardnumber };
				} elsif ( $dberror ) {
						($dberror =~ /patronimage_fk1/) ? $filerrors{'IMGEXISTS'} = 1 : $filerrors{'DBERR'} = 1;
						push my @filerrors, \%filerrors;
						push @{ $count{filenames} }, { filerrors => \@filerrors, source => $filename, cardnumber => $cardnumber };
						$template->param( ERRORS => 1 );
				} elsif ( !$mimetype ) {
					$filerrors{'MIMERR'} = 1;
					push my @filerrors, \%filerrors;
					push @{ $count{filenames} }, { filerrors => \@filerrors, source => $filename, cardnumber => $cardnumber };
					$template->param( ERRORS => 1 );
				}
			} else {
			#	$count{count}--;
				$filerrors{'CORERR'} = 1;
				push my @filerrors, \%filerrors;
				push @{ $count{filenames} }, { filerrors => \@filerrors, source => $filename, cardnumber => $cardnumber };
				$template->param( ERRORS => 1 );
			}
		} else {
			$filerrors{'OPNERR'} = 1;
			push my @filerrors, \%filerrors;
			push @{ $count{filenames} }, { filerrors => \@filerrors, source => $filename, cardnumber => $cardnumber };
			$template->param( ERRORS => 1 );
		}
    } else {    # The need for this seems a bit unlikely, however, to maximize error trapping it is included
        $filerrors{'CRDFIL'} = ($cardnumber ? "filename" : ($filename ? "cardnumber" : "cardnumber and filename")); 
        push my @filerrors, \%filerrors;
		  push @{ $count{filenames} }, { filerrors => \@filerrors, source => $filename, cardnumber => $cardnumber };
#        $template->param( ERRORS => 1 );
    }
    return (%count);
}

__END__
