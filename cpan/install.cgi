#!/usr/local/bin/perl
# install.cgi
# Install a downloaded perl module

require './cpan-lib.pl';
&ReadParse();
@pfile = split(/\0/, $in{'pfile'});

if ($in{'need'}) {
	# Some pre-reqs are needed .. return to the download form
	@cpan = ( split(/\0/, $in{'needreq'}), split(/\0/, $in{'mod'}) );
	unlink(@pfile);		# will re-get
	&redirect("download.cgi?source=3&cpan=".&urlize(join(" ", @cpan)));
	}

foreach $pfile (@pfile) {
	-r $pfile || &error(&text('install_efile', "<tt>$pfile</tt>"));
	}
&ui_print_unbuffered_header(undef, $text{'install_title'}, "");

# Set environment variables
for($i=0; defined($in{"name_$i"}); $i++) {
	if ($in{"name_$i"} ne "") {
		$ENV{$in{"name_$i"}} = $in{"value_$i"};
		}
	}

# Go through all the modules
@mods = split(/\0/, $in{'mod'});
@dirs = split(/\0/, $in{'dir'});
$perl_path = &get_perl_path();
for($i=0; $i<@mods; $i++) {
	print &text('install_doing_'.$in{'act'}, "<tt>$mods[$i]</tt>"),"<p>\n";

	# Untar the perl module
	$mod_dir = &transname($dirs[$i]);
	($mod_par = $mod_dir) =~ s/\/[^\/]+$//;
	system("rm -rf $mod_dir >/dev/null 2>&1");
	&show_output($text{'install_untar'}, $mod_par,
		     "gunzip -c $pfile[$i] | tar xvf -");

	if (-r "$mod_dir/Makefile.PL") {
		# Run Makefile.PL and make
		&show_output($text{'install_make'}, $mod_dir,
			     "$perl_path Makefile.PL $in{'args'} && make") ||
			&build_error();

		# Run make test (if requested)
		if ($in{'act'} == 1 || $in{'act'} == 3) {
			&show_output($text{'install_test'}, $mod_dir,
				     "make test") || &build_error();
			}

		# Run make install (if requested)
		if ($in{'act'} == 2 || $in{'act'} == 3) {
			&show_output($text{'install_install'}, $mod_dir,
				     "make install") || &build_error();
			}
		}
	else {
		# Run Build.PL and Build
		&show_output($text{'install_make'}, $mod_dir,
			     "$perl_path Build.PL $in{'args'} && ./Build") ||
			&build_error();

		# Run Build test (if requested)
		if ($in{'act'} == 1 || $in{'act'} == 3) {
			&show_output($text{'install_test'}, $mod_dir,
				     "./Build test") || &build_error();
			}

		# Run Build install (if requested)
		if ($in{'act'} == 2 || $in{'act'} == 3) {
			&show_output($text{'install_install'}, $mod_dir,
				     "./Build install") || &build_error();
			}
		}

	# Clean up files
	print "<p>",&text('install_done_'.$in{'act'}, "<tt>$mods[$i]</tt>"),
	      "<p>\n";
	system("rm -rf $mod_dir") if ($mod_dir && -d $mod_dir);
	}
&clean_up(1);

# clean_up(success)
sub clean_up
{
system("rm -rf $mod_dir") if ($mod_dir && -d $mod_dir);
unlink(@pfile) if ($in{'need_unlink'} && (!$config{'save_partial'} || $_[0]));
&ui_print_footer($in{'return'}, $in{'returndesc'} || $text{'index_return'});
}

# show_output(desc, dir, command)
sub show_output
{
local (%seen, $endless_loop);
print &ui_table_start($_[0], undef, 2);
local $msg = "<pre>".&text('install_exec', $_[2])."\n";
$msg .= (" " x 100)."\n";
open(CMD, "(cd $_[1] ; $_[2]) 2>&1 </dev/null |");
while(<CMD>) {
	if ($seen{$_}++ > 100) {
		$endless_loop = 1;
		$msg .= "\n$text{'install_loop'}\n";
		last;
		}
	while(length($_) > 100) {
		s/^(.{100})//;
		$msg .= &html_escape($1)."\n";
		}
	$msg .= &html_escape($_);
	}
close(CMD);
$msg .= "</pre>";
print &ui_table_row(undef, $msg, 2);
print &ui_table_end();
return $? || $endless_loop ? 0 : 1;
}

sub build_error
{
print "<p>",&text('install_err', "<tt>$mods[$i]</tt>"),"<br>\n";
if ($in{'source'} == 3) {
	print &text('install_err2', "<tt>perl -MCPAN -e shell</tt>"),"\n";
	}
print "<p>\n";
if ($in{'need_unlink'} && $config{'save_partial'}) {
	# File needs to be deleted
	print &text('install_needunlink',
		"delete_file.cgi?".
		join("&", map { "file=".&urlize($_) } @pfile)),"<p>\n";
	}
&clean_up(0);
exit;
}

