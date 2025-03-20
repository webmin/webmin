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
for (split(/&/, $ENV{'QUERY_STRING'})) {
	my ($k, $v) = map { &html_strip(&un_urlize($_)) } split(/=/, $_, 2);
	if ($k eq "replace_what") { $what = $v }
	elsif ($k eq "replace_with" && defined $what) {
		push(@help_replacements, { $what => $v }); undef($what); }
	}

# if it ends with .gif assume it is a direct URL
if ($file =~ /\.(gif|jpg|jpeg|png)$/i) {
	&redirect("$module/$file");
	exit;
}

# Read the help file
$help = &read_help_file($module, $file);
$help || &helperror(&text('help_efile3',
		&html_escape($file), &html_escape($module)));

# Modify help file based on module
if (&foreign_exists($module) &&
    &foreign_require($module) &&
    &foreign_defined($module, 'help_pre_load')) {
	$help = &foreign_call($module, "help_pre_load", $help);
	}

# Modify help based on replacements when "help_pre_load" cannot be used
foreach my $r (@help_replacements) {
	foreach $k (keys %$r) {
		$help =~ s/\Q$k\E/$r->{$k}/g;
		}
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

