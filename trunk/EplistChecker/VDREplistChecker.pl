#!/usr/bin/perl -w
#
##########################################################################
#
#
$Version = "0.1.2";
#
# Date:    2006-11-01
#
# Author: Mike Constabel <vejoun @ vdrportal . de>
#                        <vejoun @ toppoint . de>
#
# See "VDREplistChecker.pl --help" for help.
#
##########################################################################

###########
# Modules #
###########
use Getopt::Long;
use Pod::Usage;
use File::Basename;
use warnings;

###########

my %Config = (InFile => "", OutFile => "", Force => 0, Debug => 0, man => 0, help => 0, quiet => 0);
my @EpisodesFile;

Getopt::Long::Configure ("bundling_override");
GetOptions (\%Config,   'InFile|i=s', 'OutFile|o=s', 'Force|f!', 'Debug|d!', 'help|h|?', 'quiet|q:+', 'man', 'version');

if ( $Config{version} )				{ print ($0." Version ".$Version."\n"); exit; }
pod2usage(-exitstatus => 0, -verbose => 2)	if ( $Config{man} );
pod2usage(1)					if ( $Config{help} || ! $Config{InFile} );

if ( -d $Config{InFile} && $Config{InFile} !~ /\/$/ ) {
  $Config{InFile} .= "/";
}

if ( -d $Config{OutFile} && $Config{OutFile} !~ /\/$/ ) {
  $Config{OutFile} .= "/";
}

my @Files;

if ( $Config{InFile} =~ /\/$/ && -d $Config{InFile} ) {
  my @Episoden_Dir = glob $Config{InFile}."*.episodes";
  foreach ( @Episoden_Dir ) {
    push(@Files, $_) if ( ! -l $_ );
  }
} elsif ( $Config{InFile} && -f $Config{InFile} ) {
  push(@Files, $Config{InFile});
} else {
  print "Please provide an existing file or a path with parameter -i.\n";
  exit 1;
}

my $InFile = $OutFile = "";
my $errors = $warnings = 0;

foreach ( @Files ) {
  $InFile = $_;
  $errors = $warnings = $infos = 0;
  my @Msg = ();

  open (FILE, "<".$InFile) || die("Error opening ".$InFile);
  @EpisodesFile = <FILE>;
  close FILE;

  if ( $Config{OutFile} =~ /\/$/ && -d $Config{OutFile} ) {
    my ($filename, $directories, $suffix) = fileparse($InFile, qr/\.[^.]*/);
    $OutFile = $Config{OutFile}.$filename.$suffix;
  }

  if ( $OutFile && -s $OutFile && ! $Config{Force} ) {
    print STDERR $OutFile .": Output file already exists! Specify -f if you want me to force overwriting it.\n";
    next;
  }

  my %LineField = ();
  my $Seasonlist = 0;
  my $i = $tmp = 0;
  my @SeasonList;
  my $Season = $Stop = 0;

  $Seasonlist		= 0;
  $i = $linenumber	= 0;
  $firstline		= 1;
  $alternative		= 0;
  my @Data		= ();
  my @Comments		= ();
  my @Keywords		= ();
  my %LastLineField	= ();

  push(@SeasonList, "#");
  push(@SeasonList, "# SEASONLIST");

  foreach( @EpisodesFile ) {
    chomp;
    $Line = $_;
    $Line =~ s/(\s*$|\r|\n)//g;

    $linenumber++;

    if ( $Line =~ /^#\s*SEASONLIST/ ) { $Seasonlist = 1; next; }
    if ( $Line =~ /^#\s*\/SEASONLIST/ ) { $Seasonlist = 0; next; }
    next if $Seasonlist;

    if ( $Line =~ /^\s*(\d+)\s*\t\s*(\d+)\s*\t\s*(\d+)\s*\t\s*(.*?)\s*\t\s*(.*?)\s*$/ || $Line =~ /^\s*(\d+)\s*\t\s*(\d+)\s*\t\s*(\d+)\s*\t\s*(.*?)\s*$/ || $Line =~ /^\s*(\d+)\s*\t\s*(\d+)\s*\t\s*(\d+)\s*$/ ) {
      %LineField = ( Season => $1+0, Episode => $2+0, EpisodeOverAll => $3+0, Subtitle => ( defined $4 && $4 ) ? $4 : "n.n.", Miscellaneous => ( defined $5 && $5 ) ? $5 : "");

      $LineField{Subtitle} =~ s/^\s*nn\s*$/n\.n\./;
      $LineField{Subtitle} =~ s/ +/ /g;
      
      %LastLineField = %LineField if $firstline;

      $alternative = 1 if ( $LineField{Miscellaneous} =~ /^\s*#\s*alternative\s*$/ );

      $i++ if (! $alternative && $LineField{Season});

      if ( ($LineField{Season} + 0) != $tmp && $tmp ) {
        push(@SeasonList, "# ".($tmp + 0)."\t".($i - $Stop)."\t".($i - 1));
        $tmp = $LineField{Season};
        $Stop = 1;
      } else {
        $tmp = $LineField{Season} if ! $tmp;
        $Stop++;
      }

      if ( ( $LineField{Season} > $LastLineField{Season} && $LineField{Episode} == 1 ) ||
           ( $LineField{Season} == $LastLineField{Season} && $LineField{Episode} == $LastLineField{Episode}+1 ) ||
           ( $LineField{Season} == $LastLineField{Season} && $LineField{Episode} == $LastLineField{Episode} && $alternative ) || $firstline ) {
        $emptyline	= 0;
        $alternative	= 0;
        if ( $firstline ) {
          push(@Data, "#");
          push(@Data, sprintf("#SE\tEP\tNo.\tTitle"));
          push(@Data, "#");
        }
        if ( $LineField{Season} > $LastLineField{Season} || $firstline ) {
          push(@Data, sprintf("# %02i. Staffel", $LineField{Season}));
        }
        $firstline = 0 if $firstline;
        $LineField{Miscellaneous} = "\t".$LineField{Miscellaneous} if ( $LineField{Miscellaneous} );
        push(@Data, sprintf("%02i\t%i\t%i\t%s%s", $LineField{Season}, $LineField{Episode}, $i, $LineField{Subtitle}, $LineField{Miscellaneous}));
      } else {
        $errors++ unless $Config{quiet} >= 3;
        push(@Msg, sprintf ("%s:%i: Syntax error: Please check the line, especially the season and episode numbering!\n", $InFile, $linenumber)) unless $Config{quiet} >= 3;
      }
    } elsif ( $Line =~ /^#\s*SHORT(TITLE)?\s*(.*?)\s*$/i && ! $i ) {
      my $short = $2;
      $short =~ s/_+/ /g;
      $short =~ s/ +/ /g;
      $emptyline = 0;
      push(@Keywords, "#");
      push(@Keywords, "# SHORT ".$short);
      $short = "";
    } elsif ( $Line =~ /^#\s*COMPLETE\s*$/i && ! $i ) {
      $emptyline = 0;
      push(@Keywords, "#");
      push(@Keywords, "# COMPLETE");
    } elsif ( $Line =~ /^#\s*SE\tEP/ ) {
      $infos++ if ! $Config{quiet};
      push(@Msg, sprintf ("%s:%i: Info: Skipping not needed line.\n", $InFile, $linenumber)) if ! $Config{quiet};
    } elsif ( $Line =~ /^#\s*(\d+.*staffel|staffel.*\d+)\s*\S*$/i ) {
      $infos++ if ! $Config{quiet};
      push(@Msg, sprintf ("%s:%i: Info: Skipping not needed line.\n", $InFile, $linenumber)) if ! $Config{quiet};
    } elsif ( $Line =~ /^#.+/ && ! $i ) {
      $emptyline = 0;
      push(@Comments, $Line);
    } elsif ( $Line =~ /^\s*$/ && ! $i ) {
      $infos++ if ! $Config{quiet} && $emptyline;
      push(@Msg, sprintf ("%s:%i: Info: Skipping not needed empty line.\n", $InFile, $linenumber)) if ! $Config{quiet} && $emptyline;
      $emptyline++;
    } elsif ( $Line =~ /^$/ && ! $emptyline ) {
      push(@Data, $Line);
      $emptyline++;
    } elsif ( $Line =~ /^$/ && $emptyline ) {
      #push(@Data, $Line);
      $emptyline++;
    } elsif ( $i ) {
      $warnings++ unless $Config{quiet} >= 2;
      push(@Msg, sprintf ("%s:%i: Warning: Skipping unknown line.\n", $InFile, $linenumber)) unless $Config{quiet} >= 2;
    }
    %LastLineField = %LineField;
  }	

  $i++;
  push(@SeasonList, "# ".($tmp + 0)."\t".($i - $Stop)."\t".($i - 1));
  push(@SeasonList, "# /SEASONLIST");

  my @VARS = (\@Keywords, \@Comments, \@SeasonList, \@Data);
  my @Output = ();
  foreach my $ref (@VARS) {
    foreach(@$ref) {
      push(@Output, $_."\n");
    }
  }

  if ( ! $errors && $OutFile && ( ! -s $OutFile || $Config{Force} ) ) {
    open(FILE, ">".$OutFile) || die("Cannot open output file ".$OutFile);
    foreach(@Output) { print FILE $_ }
    close FILE;
  } elsif ( ! $errors ) {
    foreach(@Output) { print $_ }
  }

  print STDERR "\n" if ( ! $OutFile );

  foreach(@Msg) { print STDERR $_ }

  print STDERR "\n" if ( scalar @Msg > 0 );

  if ( $errors ) {
    printf STDERR ("File not accepted: %s; %i errors, %i warnings, %i infos.\n", $InFile, $errors, $warnings, $infos) unless $Config{quiet} >= 3;
  } elsif ( $warnings ) {
    printf STDERR ("File accepted: %s; %i warnings, %i infos.\n", $InFile, $warnings, $infos) unless $Config{quiet} >= 2;
  } elsif ( $infos ) {
    printf STDERR ("File accepted: %s; %i infos.\n", $InFile, $infos) unless $Config{quiet} >= 1;
  } else {
    printf STDERR ("File accepted: %s\n", $InFile) unless $Config{quiet} >= 3;
  }
}

if ( $Config{InFile} && -f $Config{InFile} && $errors ) {
  exit 2;
} elsif ( $Config{InFile} && -f $Config{InFile} && $warnings ) {
  exit 3;
} else {
  exit 0;
}

__END__

=head1 NAME

VDREplistChecker -  Reads eplists (.episodes files) and writes them optimized and corrected to STDOUT or file.

=head1 SYNOPSIS

VDREplistChecker.pl -i=<> -o=<> [options...]

 Help options:

   --help | -h | -?             brief help message
   --man                        full documentation

 Needed options:

      -i			Input file or path
      -o			Output file or path
      -f			Force overwriting existing output files
      -q			Dont't print infos
      -qq			Don't print infos, warnings
      -qqq			Don't print infos, warnings, errors
      
=head1 OPTIONS

=over 8

=item B<-help>

Print a brief help message and exits.

=item B<-man>

Prints the manual page and exits.

=back

=head1 DESCRIPTION

B<VDREplistChecker.pl> reads eplists and writes them optimized and corrected to STDOUT or file.

You can use one file or an directory as input. If you choose directory, it scans the directory for
files with the suffix I<.epiosdes>.

Then the script analyses each list.
The episodes numbers are checked for correct order and uniqueness. Empty lines and unwanted lines
are discarded and an seasonlist is generated.

Syntax errors are reported to STDERR and the next file will be checked.

If there are no uncorrectable errors, the list is written to STDOUT, file, if you give an file as
I<-o> paramter or to an file (with the same name as the input file) in a directory,
if you give an directory as I<-o> paramter.

Existing files will not be overwritten unless you use I<-f>.

=head1 How to get episode files

The episode files can be found there:

Overview:

C<http://svn.berlios.de/wsvn/seasonepisode/trunk/episodes/>

Download:

C<svn checkout svn://svn.berlios.de/seasonepisode/trunk/episodes>

If you have more episode list, feel free to send it to me.

C<vejoun at users.berlios.de>

=head1 COPYRIGHT and LICENSE

Copyright (c) 2006 Mike Constabel

L<http://www.constabel.net/vdr/>

This  is free software.  You may redistribute copies of it under the terms of the GNU General Public License <http://www.gnu.org/licenses/gpl.html>.
There is NO WARRANTY, to the extent permitted by law.

=cut

