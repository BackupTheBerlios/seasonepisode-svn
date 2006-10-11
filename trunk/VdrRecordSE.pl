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
# keine Umbenennung während Aufnahme noch läuft OK
# silent mode für Hintergrundarbeit OK
# release ?

# Dieses Script modifiziert die Aufnahmeverzeichnisse von Serien im VDR nach extern vorgegeben Schemata zum Format Season Episode
# Die Formatierung der externen .episoden dateien ist in den Beispieldateien erklärt.
my $LastEdit = "07.10.2006";
my $use = "\$ VdrRecordSE.pl [-h -s -p] [-c {ConfigDir] [-i VideoDir] [ -f {\"\%N \%S \%E \%T\"} ]

-h	help : Zeige die eingebaute Hilfe an, sonst nix

-s	silent : Unterdrücke alle Printausgaben des Scripts, sinnvoll bei Hintergrundanwendung innerhalb des VDR etwa

-p	pretend : führe keine Änderungen  im Filesystem durch, zeigt nur an, was das Script tun würde

-c	config Dir : Verzeichnis, in dem sich die .episoden Dateien der verschiedenen Serien befinden
	default : /etc/vdr/plugins/

-i 	Video Dir : Ort des VDR - Videoverzeichnisses
	default : /video/

-f 	Format der Ausgabe \"\%S \%E \%N \%T\" , damit kann man ähnlich printf das Format der Ausgabe ändern :
		\%S 		Nummer der Staffel
		\%E		Nummer der Episode
		\%N		fortlaufende Nummer durch alle Episoden	
		\%T		Der Titel der Episode
	
	Default :  -f \"\%S.\%E-\%T\"
	vorher  : CSI_Den_Tätern_auf_der_Spur/Wer_zuletzt_lacht
	nachher : CSI_Den_Tätern_auf_der_Spur/03.20-Wer zuletzt lacht
	
	Beispiele : 
	-f \"\%N_\%S.\%E-\%T\"
	vorher  : CSI_Den_Tätern_auf_der_Spur/Wer_zuletzt_lacht
	nachher : CSI_Den_Tätern_auf_der_Spur/66_03.20-Wer zuletzt lacht

	-f \"\%S-\%E-(\%N)---\%T\"
	vorher  : CSI_Den_Tätern_auf_der_Spur/Wer_zuletzt_lacht
	nachher : CSI_Den_Tätern_auf_der_Spur/03-20-(66)---Wer zuletzt lacht

Beispielaufruf :
\$ VdrRecordSE.pl -c /home/alex/meine_episoden_dateien/ -i /video/ -f \"\%N_\%S.\%E-\%T\" -p 

Dieses Script modifiziert die Aufnahmeverzeichnisse von Serien im VDR nach extern vorgegeben Schemata zum Format \"Season-Zähler-Episode\".
Serien müssen dazu im Format Serie/Episode vorliegen, meint :
.../Star_Trek:_Deep_Space_Nine/Das_Melora-Problem/2006-09-29.22.35.50.50.rec/...

Die Episodendateien ( textbasierende Datenbank-Dateien, die die Zuordnungen von Epsioden zu ihren Nummern enthalten ) 
können und sollen von den Usern erweitert und korrigiert werden.
Welches Format zu beachten ist, steht in den Beispieldateien drin.
Was mit der Umbennenung gemeint ist, zeigt am besten das bekannte Vorher <-> Nachher Beispiel :

alt :\t/video/Star_Trek:_Deep_Space_Nine/Das_Melora-Problem
neu :\t/video/ST-DSN/2.06-Das_Melora-Problem

Serien, die nicht zugeordnet werden können bleiben, wie sie sind, genauso auch die Spielfilme ( wer nimmt denn sowas auf ? )

Für das unscharfe Suchen und Vergleichen brauchen wir ein Zusatzmodul ( String::Approx ) aus dem CPAN, keine Angst :
Mit :
\$ perl -MCPAN -e 'install String::Approx' 
könnt ihr es euch schnell vom CPAN holen

Viel Spaß
alexanderrichter\@gmx.net
" ;
###debug
#my $getEPG = 1 ;

our( $opt_s , $opt_h , $opt_i , $opt_c , $opt_p , $opt_f ) ;
getopts("shi:c:pf:") ;
#print "$opt_s\n" ;
$opt_s = $opt_s || 0 ;
$opt_f = $opt_f || "%S.%E-%T" ;
print_mess ("-f  $opt_f erkannt\n") ;
if ( $opt_s == 1 ) { sleep 3 ; }
$opt_h and print ( "-h erkannt\n$use" ) and exit 1 ; 
$opt_p and print_mess ("-p erkannt !!! Änderungen werden nur angezeigt, aber nicht durchgeführt !\n\n") ;
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
return unless ( $File::Find::name =~ /.*rec\/index.vdr?/ ) ;
push ( @VideoList , $File::Find::name ) ;
}

###################################################################################################

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
# 	Aufnahmen die nicht älter als 2 Sekunden überspringen wir, die Aufnahme läuft bestimmt noch
	next if ( $time - $index_write < 2 ) ;

##### Aufnahme verzeichnis auslesen Ende
		my $NSerie  ;
		my $NEpisode ;
		if ( $OEpisode =~ /\(.*/ )  { $OEpisode = $` ; }
#
		my $matched_by_episodes = 0 ;
		## Ab hier wird spannend , wir vergleichen den Serientitel mit den Episodenlistentiteln	
		foreach  ( sort keys %Episoden_Lists ) { 
#			print "foreach  \( sort keys \%Episoden_Lists $_\n" ;
			if ( amatch ("$OSerie" , ["30%"] , "$_")) {
				my ( $match_in_episodes , $ZahlS , $ZahlE , $ZahlN , $NSerie ) = finde_SE_in_episodes_Datei ( $Episoden_Lists{$_} , $OEpisode ) ;
				if ( defined $match_in_episodes and $match_in_episodes eq 1 ) { 
#					print "$match_in_episodes $ZahlS , $ZahlE , $ZahlN , $OEpisode\n" ;
					$NEpisode = formatiere_neuen_episodennamen  ( $OEpisode , $ZahlS , $ZahlE , $ZahlN , $opt_f ) ;
#					print "\$NEpisode $NEpisode\n" ;
					unless ( defined $NSerie ) { $NSerie  =  ${OSerie} ; } 
					move_old_to_new ( $OSerie , $OEpisode , $NSerie , $NEpisode , $Zeile , $opt_i , $opt_p ) ;
					$matched_by_episodes = 1 ;
				last ;
				}
			}
		}
		unless  ( $matched_by_episodes eq 1 ) { 
#			print "not matched_by_episodes\n" ;
			if ( find_Infos_by_premiere_epg ( $Zeile , $OSerie , $OEpisode , $opt_c ) ) {
				print "matched_by_premiere_epg :-)\n" ;
				# harter hack : ich rufe mich selbst nochmal auf :
#				print "$0 -s -i $opt_i -c  $opt_c -f $opt_f\n" ;
				unless ( $opt_p ) { system ("$0 -s -i $opt_i -c  $opt_c -f $opt_f") ; }
			}	
		}
}
#		print_mess ("keine vorhanden Infos gefunden für : $OSerie\n") ;
#		find_Infos_by_premiere_epg ( $Zeile , $OSerie , $OEpisode , $opt_c ) ;
unless ( $opt_p ) { system ("touch $opt_i.update")  ; }		
###################################################################################################

#### Ab hier nur noch Funktionen :


			sub move_old_to_new {
			# erwartet ( $OSerie , $OEpisode , $NSerie , $NEpisode , $Zeile , $opt_i , $opt_p )
			# gibt zurück ()
			### code 
			my $OSerie = $_[0] ; 
			my $OEpisode = $_[1] ; 
			my $NSerie = $_[2] ;
			my $NEpisode = $_[3] ;
			my $Zeile = $_[4] ;
			my $opt_i = $_[5] ;
			my $opt_p = $_[6] ;

			my @CurrFile = split ( "/" , $Zeile ) ;
			shift @CurrFile  ; # 1. element wegschneiden, weil split ein erstest leeres element liefert

#				unless ( $NEpisode eq "nn" ) {
					print_mess ( "vorher\t: ${OSerie}\/${OEpisode}\n" ) ;
					print_mess ( "nachher\t: ${NSerie}\/${NEpisode}\n\n" ) ;
					unless ( $opt_p ) { mkdir ("$opt_i${NSerie}")  ; }
					unless ( $opt_p ) { mkdir ("$opt_i${NSerie}/${NEpisode}") ; }

					# für das verschieben das Inhalts ins neue verzeichnis brauchen wir wir die original Verzeichnis beschreibung
#					print "@CurrFile\n" ;
					# das kopiern wir erstmal 
					my @OrigDir = @CurrFile ;
					splice @OrigDir, $#OrigDir -1 ; # die letzten beiden elemente 2006-09-29.22.35.50.50.rec index.vdr braucht keiner		
#					print "@OrigDir\n" ;
					$"="/" ;
					my $OrigDirPfad = "/@OrigDir/" ;
					splice @OrigDir, $#OrigDir ;
					my $OrigDirPfadRem = "/@OrigDir" ;
					$"=" " ;
#					print "$OrigDirPfad\n" ;
					unless ( $opt_p ) { 
						move ("$OrigDirPfad/" ,  "$opt_i${NSerie}/${NEpisode}/") ;
#						print "$OrigDirPfadRem\n" ;
						rmdir ("$OrigDirPfadRem") and print_mess ( "Leeres Verzeichnis $OrigDirPfadRem gelöscht\n" ) ;
				
					 }
#				}
			}




			sub formatiere_neuen_episodennamen {
			# erwartet ( $OEpisode , $ZahlS , $ZahlE , $ZahlN , $opt_f )
			# gibt zurück ( $neuen_namen ) 
			my $OEpisode = $_[0] ;
			my $ZahlS = $_[1] ;
			my $ZahlE = $_[2] ;
			my $ZahlN = $_[3] ;
			my $opt_f = $_[4] ;
							
						my ( $PreName  ) = $OEpisode =~ /(\[\w+\])/ ;
						( my  $Name  =  $OEpisode ) =~ s/\[\w+\]// ;
						$Name =~ s /\ +/_/g ;
						$Name =~ s /_+/_/g ;
						my %FormatHash = (
							'%S' => "$ZahlS" , 
							'%E' => "$ZahlE" , 
							'%N' => "$ZahlN" , 
							'%T' => "$Name" ) ;
						my $opt_f_work = $opt_f ;
						foreach ( '%S' , '%E' , '%T' , '%N' ) {
#							print "$_ --> $FormatHash{$_}\n" ;
							if ( $opt_f_work  =~ /$_/ ) {
#								print "$opt_f\t" ;
								$opt_f_work =~ s/$_/$FormatHash{$_}/ ;
#								print "$opt_f_work\n" ;
							}
						}
						if ( defined $PreName ) { $opt_f_work = "${PreName}${opt_f_work}" ; }
						return  $opt_f_work ;
		}






			### Wir haben eine passende episodes Datei, daher kommt hier eine Funktion, die in der Episodes Datei
			### nach dem Inhalt fandet
			sub finde_SE_in_episodes_Datei {
			### erwartet : ( EpisodenDatei ,  OEpisode )
			### gibt zurück : ( 1|0 , $ZahlS , $ZahlE , $ZahlN )

			my $EpisodesDatei = $_[0] ;
			my $OEpisode = $_[1] ;
			my $NSerie ;

			open ELIST , "$EpisodesDatei" or die "konnte $EpisodesDatei nicht öffnen" ;
				while ( my $EZeile = <ELIST> ) {
					#Season  episode fullnumber titel any_other
					#01	1	1	Es weihnachtet schwer	Simpsons Roasting on an Open Fire	7G08
					# überspringe kommentarzeilen oder mit führendem Leerzeichen beginnend, genauso mit nur einem return zeichen
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
						return 1 , $ZahlS , $ZahlE , $ZahlN , $NSerie ;
						last ;
						}	
					}
				}
				close ELIST ;
				return 0 ;
			}

sub print_mess {
my $mess = $_[0] ;
	 if ( $opt_s ne 1 ) {
		print "$mess" ;
	}
}


#### experimentelle Option ---> extrahiere Season Episode Infos aus dem info.vdr ( works only with premiere epg )

sub find_Infos_by_premiere_epg {
# braucht ( kompletter Pfad zur Aufnahme , Serie , Episode , Pfad_zu_den_episodes-Dateien )
# gibt zurück ( 1| undef )
my $RecDir = $_[0] ;
my $OSerie = $_[1] ;
my $OEpisode = $_[2] ;
my $Episodes = $_[3] ;
#my $OSerie 
### code orig :
my ( $yes , $Sea , $Epi ) = &find_SE_infos ( $RecDir ) ;
#print_mess ("$RecDir $yes , $Sea , $Epi\n") ;
if ( $yes eq 1 ) {
	unless ( durchsuche_episodes ( "${Episodes}${OSerie}.episodes" , $Sea , $Epi ) ) {
#		print "durchsuche_episodes hat nix gefunden, cool\n" ;
		my $OEpisode_print = $OEpisode ;
		$OEpisode_print =~ s/\[w+\]// ;
		$OEpisode_print =~ s/\d+\.\d+\-// ;
		unless ( $opt_p ) {
			erweitere_episodes ( "${Episodes}${OSerie}.episodes" , $Sea , $Epi , "nn" , $OEpisode_print )  ;
		}
		print_mess ( "Neuer Eintrag in ${Episodes}${OSerie}.episodes --> $Sea $Epi  nn  $OEpisode_print\n" ) ;
		return 1 ;
	}
}
}




sub erweitere_episodes {
## erwartet ( episodes-Datei , Serie-numerisch , Episode-numerisch , Nummerierung|nn , Serientitel )
## gibt zurück ( 1|undef )
if ( $_[1] =~ /^\d{1}$/ ) { $_[1] = "0$_[1]" ; } # führende Null dran, wenn nötig
if ( $_[2] =~ /^\d{1}$/ ) { $_[2] = "0$_[2]" ; } # führende Null dran, wenn nötig
my $new = "$_[1]\t$_[2]\t$_[3]\t$_[4]" ;
my @all ;
open FH , "$_[0]" and @all = <FH> and close FH and chomp @all ;
push @all , $new ;
my @sortet = sort @all ;
	unless ( -f "$_[0].new" ) {
		open FHNEW , ">$_[0].new" or die "konnte nicht öffnen" ; 
		foreach ( @sortet ) { print FHNEW "$_\n" ; }
		close FHNEW ;
		move ( "$_[0].new" , "$_[0]" ) ;
	}
return undef ;
}


#if ( durchsuche_episodes ( $Dir , $S , $E ) ) { print "yes\n" } ;
#if ( defined $a ) { print "$Dir , $S , $E , $a\n" } ;

## eine funktion, die in einer episodes Datei nach einem Serie Episode Muster schaut
sub durchsuche_episodes {
## erwartet ( episodes-Datei , suchinhalt-Serie-numerisch , suchinhalt-Episode-numerisch )
## gibt zurück ( 1|undef )
return undef unless ( -f $_[0] ) ;
if ( $_[1] =~ /^\d{1}$/ ) { $_[1] = "0$_[1]" ; } # führende Null dran, wenn nötig
if ( $_[2] =~ /^\d{1}$/ ) { $_[2] = "0$_[2]" ; } # führende Null dran, wenn nötig
open FH , "$_[0]" or return undef ;
 while ( my $zeile = <FH> ) {
	if ( $zeile =~ /^$_[1]/ and $zeile =~ /^\d+\t$_[2]/ ) { return 1 }
}
close FH ;
return undef ;
}



#my $Dir = $ARGV[0] ;
#my  ( $yes , $Episoden_Lists ) ;
#my ( $yes , $Episoden_Lists ) = &hole_episodes ( $Dir , "episodes" ) ;
#my %Episoden_Lists = %$Episoden_Lists  ; # Kopie von der Hashreferenz, besser zu lesen
#print "$yes  $Episoden_Lists\n" ; 

#Wir holen uns einen Hash mit allen episoden Dateien
sub hole_episodes {
## erwartet ( Verzeichnis , Dateiendung )
## sendet ( 1|0 , HashRef ) # key -> name der episodendatei , vallue -> Ort der Datei
## Verzeichnis mit den Ersetzungslisten einlesen :
#print "$_[0] , $_[1]\n" ;
return 0 unless ( -d "$_[0]" ) ;
my @Episoden_Dir = glob "$_[0]*$_[1]"  ;
my %Episoden_Lists ;
	foreach ( @Episoden_Dir ) {
#		print "$_\n" ;
		my $clean_Epsioden_list_name = basename ( $_ ) ;
		$clean_Epsioden_list_name =~ s/\.episodes// ;
		if ( not defined $Episoden_Lists{$clean_Epsioden_list_name} ) {
			$Episoden_Lists{$clean_Epsioden_list_name} = $_ ;
		}
	}
return 1 , \%Episoden_Lists ;
}


# ein Funktion zum herausfiltern der season episode Info aus der info.vdr Datei
#my $Dir = $ARGV[0] ;

#my ( $yes , $Sea , $Epi ) = &find_SE_infos ( $Dir ) ; 
#if ( $yes eq 1 ) { print "$Sea\.$Epi\n" ; }

# ein Funktion zum herausfiltern der season episode Info aus der info.vdr Datei bei EPG-Daten von Premiere
sub find_SE_infos {
# erwartet ( Directory )
# retuniert ( 1|0 , Season , Episode )
my @CF = split ( "/" , $_[0] ) ;
shift @CF  ; # 1. element wegschneiden, weil split ein erstes leeres element liefert
splice @CF , $#CF ;
$"="/" ;
my $newCF = "/@CF/info.vdr" ;
$"=" " ;
my ( $Sea , $Epi ) ;
open INFO , "$newCF" or die "konnte $newCF nicht öffnen" ;
	while ( my $zeile = <INFO> ) {
		next unless ( $zeile =~ /^D\ / ) ;
		( $Sea , $Epi ) = $zeile =~ /^D\ (\d+)\..*Folge\ (\d+)\:/ ;
	}
	if ( defined $Sea and defined  $Epi ) {
		if ( $Sea =~ /^\d{1}$/ ) { $Sea = "0$Sea" ; } # führende Null dran, wenn nötig
		if ( $Epi =~ /^\d{1}$/ ) { $Epi = "0$Epi" ; } # führende Null dran, wenn nötig
	return 1 , $Sea , $Epi ;
	}
	else { return 0 , 0 , 0 }
}
