#!/usr/bin/perl 

use strict ;
use locale ;
use warnings ;
use File::Basename ;
use File::Copy ;
use File::Find ;
use Getopt::Std ;


###perl -MCPAN -e 'install String::Approx'
use String::Approx qw (amatch) ;

# TODO :
# keine Umbenennung w�hrend Aufnahme noch l�uft OK
# silent mode f�r Hintergrundarbeit OK
# release ?

# Dieses Script modifiziert die Aufnahmeverzeichnisse von Serien im VDR nach extern vorgegeben Schemata zum Format Season Episode
# Die Formatierung der externen .episoden dateien ist in den Beispieldateien erkl�rt.
my $LastEdit = "04.10.2006";
my $use = "\$ VdrRecordSE.pl [-h -s -p] [-c {ConfigDir] [-i VideoDir] [ -f {\"\%N \%S \%E \%T\"} ]

-h	help : Zeige die eingebaute Hilfe an, sonst nix

-s	silent : Unterdr�cke alle Printausgaben des Scripts, sinnvoll bei Hintergrundanwendung innerhalb des VDR etwa

-p	pretend : f�hre keine �nderungen  im Filesystem durch, zeigt nur an, was das Script tun w�rde

-c	config Dir : Verzeichnis, in dem sich die .episoden Dateien der verschiedenen Serien befinden
	default : /etc/vdr/plugins/

-i 	Video Dir : Ort des VDR - Videoverzeichnisses
	default : /video/

-f 	Format der Ausgabe \"\%S \%E \%N \%T\" , damit kann man �hnlich printf das Format der Ausgabe �ndern :
		\%S 		Nummer der Staffel
		\%E		Nummer der Episode
		\%N		fortlaufende Nummer durch alle Episoden	
		\%T		Der Titel der Episode
	
	Default :  -f \"\%S.\%E-\%T\"
	vorher  : CSI_Den_T�tern_auf_der_Spur/Wer_zuletzt_lacht
	nachher : CSI_Den_T�tern_auf_der_Spur/03.20-Wer zuletzt lacht
	
	Beispiele : 
	-f \"\%N_\%S.\%E-\%T\"
	vorher  : CSI_Den_T�tern_auf_der_Spur/Wer_zuletzt_lacht
	nachher : CSI_Den_T�tern_auf_der_Spur/66_03.20-Wer zuletzt lacht

	-f \"\%S-\%E-(\%N)---\%T\"
	vorher  : CSI_Den_T�tern_auf_der_Spur/Wer_zuletzt_lacht
	nachher : CSI_Den_T�tern_auf_der_Spur/03-20-(66)---Wer zuletzt lacht

Beispielaufruf :
\$ VdrRecordSE.pl -c /home/alex/meine_episoden_dateien/ -i /video/ -f \"\%N_\%S.\%E-\%T\" -p 

Dieses Script modifiziert die Aufnahmeverzeichnisse von Serien im VDR nach extern vorgegeben Schemata zum Format \"Season-Z�hler-Episode\".
Serien m�ssen dazu im Format Serie/Episode vorliegen, meint :
.../Star_Trek:_Deep_Space_Nine/Das_Melora-Problem/2006-09-29.22.35.50.50.rec/...

Die Episodendateien ( textbasierende Datenbank-Dateien, die die Zuordnungen von Epsioden zu ihren Nummern enthalten ) 
k�nnen und sollen von den Usern erweitert und korrigiert werden.
Welches Format zu beachten ist, steht in den Beispieldateien drin.
Was mit der Umbennenung gemeint ist, zeigt am besten das bekannte Vorher <-> Nachher Beispiel :

alt :\t/video/Star_Trek:_Deep_Space_Nine/Das_Melora-Problem
neu :\t/video/ST-DSN/2.06-Das_Melora-Problem

Serien, die nicht zugeordnet werden k�nnen bleiben, wie sie sind, genauso auch die Spielfilme ( wer nimmt denn sowas auf ? )

F�r das unscharfe Suchen und Vergleichen brauchen wir ein Zusatzmodul ( String::Approx ) aus dem CPAN, keine Angst :
Mit :
\$ perl -MCPAN -e 'install String::Approx' 
k�nnt ihr es euch schnell vom CPAN holen

Viel Spa�
alexanderrichter\@gmx.net
" ;

our( $opt_s , $opt_h , $opt_i , $opt_c , $opt_p , $opt_f ) ;
getopts("shi:c:pf:") ;
#print "$opt_s\n" ;
$opt_s = $opt_s || 0 ;
$opt_f = $opt_f || "%S.%E-%T" ;
print_mess ("-f  $opt_f erkannt\n") ;
if ( $opt_s == 1 ) { sleep 3 ; }
$opt_h and print ( "-h erkannt\n$use" ) and exit 1 ; 
$opt_p and print_mess ("-p erkannt !!! �nderungen werden nur angezeigt, aber nicht durchgef�hrt !\n\n") ;
$opt_i = $opt_i || "/video/" ;
$opt_c = $opt_c || "/etc/vdr/plugins/" ;
unless ( $opt_i =~ /\/$/ ) {  $opt_i = "$opt_i/" ; }
unless ( $opt_c =~ /\/$/ ) {  $opt_c = "$opt_c/" ; }

print_mess  ( "VdrRecordSE.pl Version $LastEdit\n\n" ) ;
unless ( -d $opt_c ) { print_mess ( "$use" ) ; exit 1 ; }
unless ( -d $opt_i and  -w $opt_i ) { print_mess ( "$use!!! Kann nicht in $opt_i  schreiben, Abbruch..." ) ; exit 1 ; }


## Verzeichnis mit den Ersetzungslisten einlesen :
my @Episoden_Dir = glob "$opt_c*episodes"  ;
my %Episoden_Lists ;
foreach ( @Episoden_Dir ) {
	my $clean_Epsioden_list_name = basename ( $_ ) ;
	$clean_Epsioden_list_name =~ s/\.episodes// ;
	if ( not defined $Episoden_Lists{$clean_Epsioden_list_name} ) {
		$Episoden_Lists{$clean_Epsioden_list_name} = $_ ;
	}
}

print_mess ( "Folgende Episodenlisten gefunden :\n" ) ;
foreach my $key ( sort keys %Episoden_Lists ) { 	
	print_mess ( "- $key \n" ) ;
}
print_mess ( "\n" ) ;


##### Aufnahme verzeichnis auslesen
my @VideoList ;
find ( \&funcfind , "$opt_i" )  ;


sub funcfind {
#return unless ( $File::Find::name =~ /.*rec\/index.vdr?/ ) ;
#return unless ( $File::Find::name =~ /.*\/.*rec\/index.vdr?/ ) ;
return unless ( $File::Find::name =~ /.*rec\/index.vdr?/ ) ;
push ( @VideoList , $File::Find::name ) ;
}


#/video/Six_Feet_Under_-_Gestorben_wird_immer/4.05-Das_ist_mein_Hund/2005-08-21.21:55.50.50.rec/ready_to_transcode.flag
foreach my $Zeile ( @VideoList ) {
	my @CurrFile = split ( "/" , $Zeile ) ;
	shift @CurrFile  ; # 1. element wegschneiden, weil split ein erstest leeres element liefert
	my $DatumElement = $CurrFile[$#CurrFile -1] ;
	my $OEpisode = $CurrFile[$#CurrFile -2] ;
	my $OSerie = $CurrFile[$#CurrFile -3] ;
#	print "$OSerie --- $OEpisode\n" ;
	next if ( $OEpisode =~ /^\d+\.\d+\-/ ) ;
	next if ( $OEpisode =~ /^\[\w{1,5}\]\d+\.\d+\-/ ) ;
# 	Zeitstempel des letzten Schreibzugriffs auf die index.vdr mtime 9.Element von Stat
	my $time = time ;
	my ( $index_write )  = ( stat ( $Zeile )) [9] ;
# 	Aufnahmen die nicht �lter als 2 Sekunden �berspringen wir, die Aufnahme l�uft bestimmt noch
	next if ( $time - $index_write < 2 ) ;

##### Aufnahme verzeichnis auslesen Ende

		my $NSerie  ;
		my $NEpisode ;
		if ( $OEpisode =~ /\_\(.*/ )  { $OEpisode = $` ; }
#
		## Ab hier wird spannend , wir vergleichen den Serientitel mit den Episodenlistentiteln	
		foreach  ( sort keys %Episoden_Lists ) { 
			#print "$_\n" ;
			if ( amatch ("$OSerie" , ["30%"] , "$_")) {	
#			print "passt : $OSerie ,$_\n" ;
				## wenns passt, die episoden datei ge�ffnet
				open ELIST , "$Episoden_Lists{$_}" or die "konnte $Episoden_Lists{$_} nicht �ffnen" ;
				while ( my $EZeile = <ELIST> ) {
					#Season  episode fullnumber titel any_other
					#01	1	1	Es weihnachtet schwer	Simpsons Roasting on an Open Fire	7G08
					# �berspringe kommentarzeilen oder mit f�hrendem Leerzeichen beginnend, genauso mit nur einem return zeichen
					next if ( $EZeile =~ /^#[^short]/ or $EZeile  =~ /^\ *\n$/ or $EZeile  =~ /^\n$/ ) ;
					chomp $EZeile ;
#					print "$EZeile\n" ;
					# wenn zeile mit "short" beginnt, steht dahinter der ersetzungsname der serie
					if ( $EZeile =~ /^#short/ ) { 
						( $NSerie ) = $EZeile =~ /^#short\s+(.*)$/ ;
						#print "aufgrund von short folgenden Namen gefunden : $NSerie\n" ;
					}
					# sonst kanns nur eine zeile mit dem Episodentitel sein, oder eben nicht passend
					else {
						my ( $ZahlS , $ZahlE , $ZahlN ,  $Name ) = split ( "\t" ,  $EZeile ) ;#=~ /^(\d+\.\d+)\ (.*)$/ ;
#						print "\$Name $Name \$OEpisode $OEpisode\n" ;
						if ( amatch ("$Name" , ["15%"] , "$OEpisode" )) {
#						print "matching : $ZahlS , $ZahlE , $ZahlN ,  $Name $OEpisode\n" ;
						my ( $PreName  ) = $OEpisode =~ /(\[\w+\])/ ;
#						print "$PreName\n" ;
						$Name =~ s /\ +/_/g ;
						$Name =~ s /_+/_/g ;
						my %FormatHash = (
							'%S' => "$ZahlS" , 
							'%E' => "$ZahlE" , 
							'%N' => "$ZahlN" , 
							'%T' => "$Name" ) ;
#							print "passt : $Name <-> $OEpisode\n" ;
						# traum wir haben das matching, also setzen wir den Namen neu
						my $opt_f_work = $opt_f ;
						foreach ( '%S' , '%E' , '%T' , '%N' ) {
#							print "$_\n" ;
							if ( $opt_f_work  =~ /$_/ ) {
#								print "$opt_f\t" ;
								$opt_f_work =~ s/$_/$FormatHash{$_}/ ;
#								print "$opt_f\n" ;
							}
						}
						if ( defined $PreName ) { $opt_f_work = "${PreName}${opt_f_work}" ; }
						$NEpisode = "$opt_f_work" ;
						# in der schleife haben wir alles 
						last ;
						}	
						else { $NEpisode = "nn" } 
					}
				}
				close ELIST ;
				unless ( defined $NSerie ) { $NSerie  =  ${OSerie} ; } 
				unless ( $NEpisode eq "nn" ) {
					print_mess ( "vorher\t: ${OSerie}\/${OEpisode}\n" ) ;
					print_mess ( "nachher\t: ${NSerie}\/${NEpisode}\n\n" ) ;
					unless ( $opt_p ) { mkdir ("$opt_i${NSerie}")  ; }
					unless ( $opt_p ) { mkdir ("$opt_i${NSerie}/${NEpisode}") ; }

					# f�r das verschieben das Inhalts ins neue verzeichnis brauchen wir wir die original Verzeichnis beschreibung
#					print "@CurrFile\n" ;
					# das kopiern wir erstmal 
					my @OrigDir = @CurrFile ;
					splice @OrigDir, $#OrigDir -1 ; # die letzten beiden elemente 2006-09-29.22.35.50.50.rec index.vdr braucht keiner		
#					print "@OrigDir\n" ;
					$"="/" ;
					my $OrigDirPfad = "/@OrigDir/" ;
					$"=" " ;
#					print "$OrigDirPfad\n" ;
					unless ( $opt_p ) { move ("$OrigDirPfad/" ,  "$opt_i${NSerie}/${NEpisode}/") ; }
				}
			}
		}
}	
unless ( $opt_p ) { system ("touch $opt_i.update")  ; }

sub print_mess {
my $mess = $_[0] ;
	 if ( $opt_s ne 1 ) {
		print "$mess" ;
	}
}
