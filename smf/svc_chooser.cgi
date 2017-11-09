#!/usr/local/bin/perl
# chooser.cgi
# Outputs HTML for a frame-based svc chooser

require './smf-lib.pl';

&init_config();
&ReadParse();

# type specifies svc, inst or both
$type = "both";
if (defined($in{'type'})) {
	$type = $in{'type'};
	}
if ((defined($in{'add'})) && ($in{'add'})) {
	# Only use last fmri by default
	$in{'fmri'} =~ s/\s+$//;
	if ($in{'fmri'} =~ /\n(.*)$/) {
		$in{'fmri'} = $1;
		}
	}
$fmri = $in{'fmri'};
if ($fmri =~ /^svc\:\/([^\:]*)\:*(.*)$/) {
	# fmri entered is valid
	$svc = $1;
	$inst = $2;
	}
else {
	$fmri = "svc:/";
	$svc = "";
	$inst = "";
	}
$add = int($in{'add'});

$frame = $in{'frame'};
if ($frame eq "" ) {
	$frame = 0;
}

if ($in{'frame'} == 0) {
	# base frame
	&PrintHeader();
	if ($in{'type'} eq "svc")
		{ print "<title>$text{'svc_chooser_titlesvc'}</title>\n"; }
	elsif ($in{'type'} eq "inst")
		{ print "<title>$text{'svc_chooser_titleinst'}</title>\n";}
	else
		{ print "<title>$text{'svc_chooser_titleboth'}</title>\n";}

	print "<frameset rows='*,50'>\n";
	print "<frame marginwidth=10 marginheight=10 name=topframe ",
	    "src=\"$gconfig{'webprefix'}/svc_chooser.cgi?frame=1&fmri=$fmri&add=$add&type=$type\">\n";
	print "<frame marginwidth=10 marginheight=10 name=bottomframe ",
	    "src=\"$gconfig{'webprefix'}/svc_chooser.cgi?frame=2&add=$add&fmri=$fmri&type=$type\" ",
	    "scrolling=no>\n";
	print "</frameset>\n";
	}
elsif ($in{'frame'} == 1) {
	# List of svcs
	&header();
	print <<EOF;
<script>
function svcclick(fmri, inst, expand, isvalid)
{
if ((inst == "") || (inst == ":")) {
	selected_fmri = fmri;
	}
else {
	selected_fmri = fmri+inst;
	}
curr = top.bottomframe.document.forms[0].fmri.value;
if (isvalid ==1) {
	top.bottomframe.document.forms[0].fmri.value = selected_fmri;
	}
if (expand == 1) {
	location ="svc_chooser.cgi?frame=1&add=$add&type=$type&fmri="+fmri+inst;
	}
}

</script>
EOF
	print "<b>", &text('svc_chooser_fmri', $fmri),"</b>\n";
	print "<table>\n";
	# filter fmris via fmri var
	@list = &svcs_listing("$fmri", "-sFMRI");
	foreach $f_hash (@list) {
		$full_fmri = $f_hash->{"FMRI"};
		if ($full_fmri =~ /^$fmri([^\/:]+[\/\:]*).*$/) {
			$elt = "$1";
			# check if its an instance, if so add colon
			if ($fmri =~ /.*\:$/) {
				$elt = ":$elt";
				}
			push(@flist, "$elt");
			}
		}
	@fmris = &unique(@flist);
	$uplevel = $fmri;
	if ($uplevel =~ /^svc\:\/.+$/) {
		$uplevel =~ /^svc\:\/(([^\/\:]+[\:\/])*)[^\/\:]+[\/]*[\:]*$/;
		$uplevel = "svc:/$1";
		unshift(@fmris, $uplevel);
		}
	foreach $f (@fmris) {
		print "<tr>\n";
		# determine img type
		if ($f eq $uplevel) {
			$img = "images/uplevel.gif";
			$link =
		  "<a href='javascript:svcclick(\"$uplevel\",\"\",1,0)'>";
		} elsif ($f =~ /^.*\/$/) {
			$img = "images/nextlevel.gif";
			$link =
		  "<a href='javascript:svcclick(\"$fmri$f\",\"\",1,0)'>";
		} elsif ($f =~ /^\:.*/) {
			# at instance level...
			# remove leading ":"
			$f =~ s/^\:(\S+)$/$1/;
			$img = "images/instance.gif";
			$link =
		  "<a href='javascript:svcclick(\"$fmri\",\"$f\",0,1)'>";
		} else {
			# service
			$img = "images/service.gif";
			# remove final ":" if present
			$f =~ s/^([^\:]+)\:$/$1/;
			$inst = ":";
			if ($type eq "svc") {
				# cannot click to instance level!
				# remove final ":" if present
				$isvalid = 1;
				$expand = 0;
			} elsif ($type eq "inst") {
				# cannot select svc...
				$isvalid = 0;
				$expand = 1;
			} else {
				# both valid
				$isvalid = 1;
				$expand = 1;
				}
			$link =
  "<a href='javascript:svcclick(\"$fmri$f\",\"$inst\",$expand,$isvalid)'>";
			}
		print
	"<td>$link<img border=0 width=30 height=30 src=$img></a></td>\n";
		print "<td>$link$f</a></td>\n";
		print "</tr>\n";
		}
	print "</table></td></tr></table>\n";
	&footer();
	}
elsif ($in{'frame'} == 2) {
	# Current fmri and OK/cancel buttons
	&header();
	print <<EOF;
<script>
function fmrichosen()
{
if ($add == 0) {
	top.opener.ifield.value = document.forms[0].fmri.value;
	}
else {
	if (top.opener.ifield.value != "") {
		top.opener.ifield.value += " ";
		}
	top.opener.ifield.value += document.forms[0].fmri.value;
	}
top.close();
}
</script>
EOF
	print "<table width=100%><tr><td>\n";
	print "<form onSubmit='fmrichosen(); return false'>\n";
	print
	 "<input name=fmri size=45 value=\"\">\n";
	print
	 "<input type=\"submit\" value=\"$text{'svc_chooser_ok'}\">\n";
	print "</form>\n";
	print "</td><td>\n";
	print "<form>";
	print
"<input type=\"button\" onClick='top.close()' value=\"$text{'svc_chooser_cancel'}\">";
	print "</form>";
	print "</td></tr></table></form>\n";
	&footer();
	}
