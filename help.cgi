#!/usr/local/bin/perl
# help.cgi
# Displays help HTML for some module, with substitutions

BEGIN { push(@INC, "."); };
use WebminCore;

&init_config();
&error_setup($text{'help_err'});
$ENV{'PATH_INFO'} !~ /[\\\&\;\`\'\"\|\*\?\~\<\>\^\(\)\[\]\{\}\$\n\r]/ ||
	&error($text{'help_epath'});
$ENV{'PATH_INFO'} =~ /^\/(\S+)\/(\S+)$/ || &error($text{'help_epath'});
$module = $1; $file = $2;

# if it ends with .gif assume it is a direct URL
if ($file =~ /\.(gif|jpg|jpeg|png)$/i) {
	&redirect("$module/$file");
	exit;
}

# read the help file
$help = &read_help_file($module, $file);
$help || &helperror(&text('help_efile3',
		&html_escape($file), &html_escape($module)));

# Modify help file based on module
if (&foreign_exists($module) &&
    &foreign_require($module) &&
    &foreign_defined($module, 'help_pre_load')) {
	$help = &foreign_call($module, "help_pre_load", $help);
	}

# find and replace the <header> section
if ($help =~ s/<header>([^<]+)<\/header>//i) {
	&popup_header($1);
	print &ui_subheading($1);
	}
else {
	&helperror($text{'help_eheader'});
	}

# replace any explicit use of <hr> with the ui-lib function
$uihr = &ui_hr();
$help =~ s/<hr>/$uihr/ig;

# find and replace the <footer> section
$help =~ s/<footer>/<p>/i;

# find and replace <include> directives
$help =~ s/<include\s+(\S+)>/inchelp($1)/ige;

# find and replace <if><else> directives
$help =~ s/<if\s+([^>]*)>([\000-\177]*?)<else>([\000-\177]*?)<\/if>/ifhelp($1, $2, $3)/ige;

# find and replace <if> directives
$help =~ s/<if\s+([^>]*)>([\000-\177]*?)<\/if>/ifhelp($1, $2)/ige;

# output the HTML
print $help;
&popup_footer();

# read_help_file(module, file)
# Reads the contents of a help file, either unpacked or from a ZIP
sub read_help_file
{
my ($module, $file) = @_;
my $path = &help_file($module, $file);
if (-r $path) {
	return &read_file_contents($path);
	}
my $gzpath = $path.".gz";
if (-r $gzpath) {
	my $out = &backquote_command(
		"gunzip -c ".quotemeta($gzpath)." 2>/dev/null");
	return $? ? undef : $out;
	}
my $zip = $path;
$zip =~ s/\/[^\/]+$/\/help.zip/;
if (-r $zip) {
	my @files;
	foreach my $o (@lang_order_list) {
		next if ($o eq "en");
		push(@files, $file.".".$o.".auto.html");
		push(@files, $file.".".$o.".html");
		}
	push(@files, $file.".html");
	foreach my $f (@files) {
		my $out = &backquote_command(
			"unzip -p ".quotemeta($zip)." ".
			quotemeta($f)." 2>/dev/null");
		return $out if ($out && !$?);
		}
	return undef;
	}
return undef;
}

# inchelp(path)
sub inchelp
{
my ($path) = @_;
my $inc = &read_help_file($module, $path);
if (!$inc) {
	return "<i>".&text('help_einclude3', &html_escape($path))."</i><br>\n";
	}
return $inc;
}

# ifhelp(perl, text, [elsetext])
sub ifhelp
{
my ($perl, $txt, $elsetxt) = @_;
my $rv = eval $perl;
if ($@) { return "<i>".&text('help_eif', $perl, $@)."</i><br>\n"; }
elsif ($rv) { return $txt; }
else { return $elsetxt; }
}

sub helperror
{
&header($text{'error'});
print "<center><h2>$text{'error'}</h2></center>\n";
print "<hr><p><b>",@_,"</b><p><hr>\n";
exit;
}

