#!/usr/local/bin/perl
# download.cgi
# Get a perl module from somewhere

require './cpan-lib.pl';

if ($ENV{REQUEST_METHOD} eq "POST") { &ReadParseMime(); }
else { &ReadParse(); $no_upload = 1; }
&error_setup($text{'download_err'});

if ($in{'source'} >= 2) {
	&ui_print_unbuffered_header(undef, $text{'download_title'}, "");
	}
else {
	&ui_print_header(undef, $text{'download_title'}, "");
	}

&tempname();
if ($in{'source'} == 0) {
	# installing from local file (or maybe directory)
	if (!$in{'local'})
		{ &install_error($text{'download_elocal'}); }
	if (!-r $in{'local'})
		{ &install_error(&text('download_elocal2', $in{'local'})); }
	$source = $in{'local'};
	@pfile = ( $in{'local'} );
	$need_unlink = 0;
	}
elsif ($in{'source'} == 1) {
	# installing from upload .. store file in temp location
	if ($no_upload) {
		&install_error($text{'download_eupload'});
		}
	$in{'upload_filename'} =~ /([^\/\\]+$)/;
	@pfile = ( &tempname("$1") );
	open(PFILE, ">$pfile[0]");
	print PFILE $in{'upload'};
	close(PFILE);
	$source = $in{'upload_filename'};
	$need_unlink = 1;
	}
elsif ($in{'source'} == 2) {
	# installing from URL.. store downloaded file in temp location
	$in{'url'} =~ /\/([^\/]+)\/*$/;
	@pfile = ( &tempname("$1") );
	$progress_callback_url = $in{'url'};
	if ($in{'url'} =~ /^(http|https):\/\/([^\/]+)(\/.*)$/) {
		# Make a HTTP request
		$ssl = $1 eq 'https';
		$host = $2; $page = $3; $port = $ssl ? 443 : 80;
		if ($host =~ /^(.*):(\d+)$/) { $host = $1; $port = $2; }
		&http_download($host, $port, $page, $pfile[0], \$error,
			       \&progress_callback, $ssl);
		}
	elsif ($in{'url'} =~ /^ftp:\/\/([^\/]+)(:21)?(\/.*)$/) {
		$host = $1; $file = $3;
		&ftp_download($host, $file, $pfile[0], \$error,
			      \&progress_callback);
		}
	else { &install_error(&text('download_eurl', $in{'url'})); }
	&install_error($error) if ($error);
	$source = $in{'url'};
	$need_unlink = 1;
	}
elsif ($in{'source'} == 3) {
	# installing from CPAN.. find the module, and then install it
	$in{'cpan'} || &error($text{'download_emodname'});
	$in{'cpan'} =~ s/^\s+//;
	$in{'cpan'} =~ s/\s+$//;
	$in{'cpan'} =~ s/\/+/::/g;
	@cpan = split(/\s+|\0/, $in{'cpan'});

	# First check if YUM or APT can install this module for us
	if ($config{'incyum'} && !$in{'forcecpan'}) {
		@yum = &list_packaged_modules();
		foreach $c (@cpan) {
			($yum) = grep { lc($_->{'mod'}) eq lc($c) } @yum;
			if ($yum) {
				# Module name is known
				push(@cpanyum, $yum);
				}
			elsif ($software::config{'package_system'} eq "rpm") {
				# Try to install from perl dependency
				push(@cpanyum, { 'package' => "perl($c)" });
				}
			}
		}
	if (scalar(@cpan) == scalar(@cpanyum) &&
	    defined(&software::update_system_install)) {
		# Can install from YUM or APT .. do it!
		$i = 0;
		@fallback = ( );
		foreach $yum (@cpanyum) {
			print &text('download_yum', "<tt>$cpan[$i]</tt>",
				    "<tt>$yum->{'package'}</tt>"),"<br>\n";
			print "<ul>\n";
			@got = &software::update_system_install(
				$yum->{'package'});
			print "</ul>\n";
			if (!@got) {
				# Failed, so fall back to direct install (but
				# only if not installed yet)
				eval "use $cpan[$i]";
				if ($@) {
					push(@fallback, $cpan[$i]);
					}
				}
			$i++;
			}
		if (@fallback) {
			print "<b>$text{'download_fallback'}</b><p>\n";
			@cpan = @fallback;
			}
		else {
			&ui_print_footer($in{'return'},
				 $in{'returndesc'} || $text{'index_return'});
			exit;
			}
		}

	$progress_callback_url = $config{'packages'};
	if (!-r $packages_file || $in{'refresh'}) {
		# Need to download the modules list from CPAN first
		&download_packages_file(\&progress_callback);
		print "<p>\n";

		# Make sure it is valid
		open(PFILE, $packages_file);
		read(PFILE, $two, 2);
		close(PFILE);
		if ($two ne "\037\213") {
			&install_error(&text('download_ecpangz',
					 "<tt>$config{'packages'}</tt>"));
			}
		}

	# Find each module in the modules list
	open(LIST, "gunzip -c $packages_file |");
	while(<LIST>) {
		s/\r|\n//g;
		if ($_ eq '') { $found_blank++; }
		elsif ($found_blank && /^(\S+)\s+(\S+)\s+(.*)/) {
			local $i = &indexof($1, @cpan);
			if ($i >= 0 && !$source[$i]) {
				$source[$i] = "$config{'cpan'}/$3";
				$source[$i] =~ /\/perl-[0-9\.]+\.tar\.gz$/ &&
				    &install_error(&text('download_eisperl',
						"<tt>$in{'cpan'}</tt>"));
				$sourcec++;
				}
			}
		}
	close(LIST);

	# Fail if any modules are missing from CPAN
	for($i=0; $i<@cpan; $i++) {
		push(@missing, "<tt>$cpan[$i]</tt>") if (!$source[$i]);
		}

	if ($in{'missingok'}) {
		# If missing modules are OK, exclude them from the sources list
		for($i=0; $i<@cpan; $i++) {
			if (!$source[$i]) {
				splice(@source, $i, 1);
				splice(@cpan, $i, 1);
				$i--;
				}
			}
		@cpan || &install_error(&text('download_ecpan',
					      join(" ", @missing)));
		}
	elsif (@missing) {
		# Fail due to missing modules
		&install_error(&text('download_ecpan', join(" ", @missing)));
		}
	$source = join("<br>", @source);

	# Download the actual modules
	foreach $m (@source) {
		$m =~ /\/([^\/]+)\/*$/;
		$pfile = &tempname("$1");
		$progress_callback_url = $m;
		if ($m =~ /^http:\/\/([^\/]+)(\/.*)$/) {
			# Make a HTTP request
			$host = $1; $page = $2; $port = 80;
			if ($host =~ /^(.*):(\d+)$/) { $host = $1; $port = $2; }
			&http_download($host, $port, $page, $pfile, \$error,
				       \&progress_callback);
			}
		elsif ($m =~ /^ftp:\/\/([^\/]+)(:21)?(\/.*)$/) {
			$host = $1; $file = $3;
			&ftp_download($host, $file, $pfile, \$error,
				      \&progress_callback);
			}
		else { &install_error(&text('download_eurl', $m)); }
		&install_error($error) if ($error);
		push(@pfile, $pfile);
		}
	$need_unlink = 1;
	}
else {
	&error("Unknown source mode $in{'source'}");
	}

# Check if the file looks like a perl module
foreach $pfile (@pfile) {
	open(TAR, "( gunzip -c $pfile | tar tf - ) 2>&1 |");
	while($line = <TAR>) {
		if ($line =~ /^\.\/([^\/]+)\/(.*)$/ ||
		    $line =~ /^([^\/]+)\/(.*)$/) {
			if (!$dirs{$1}) {
				$dirs{$1} = $pfile;
				push(@dirs, $1);
				}
			$file{$2}++;
			}
		$tar .= $line;
		}
	close(TAR);
	if ($?) {
		unlink(@pfile) if ($need_unlink);
		&install_error(&text('download_etar', "<tt>$tar</tt>"));
		}
	}
if (@dirs == 0 || $file{'Makefile.PL'}+$file{'Build.PL'} < @dirs) {
	# Not all files were Perl modules
	unlink(@pfile) if ($need_unlink);
	&install_error($text{'download_emod'});
	}
if ($file{'Build.PL'} && $file{'Makefile.PL'} < @dirs) {
	# Make sure we have Module::Build if using Build.PL
	eval "use Module::Build";
	if ($@) {
		unlink(@pfile) if ($need_unlink);
		&install_error(&text('download_ebuild',
				     "<tt>Module::Build</tt>"));
		}
	}
foreach $d (@dirs) {
	if ($d =~ /^(\S+)\-v?([0-9\.ab]+)$/) {
		push(@mods, $1);
		push(@vers, $2);
		}
	else {
		push(@mods, $m);
		push(@vers, undef);
		}
	$mods[$#mods] =~ s/-/::/g;
	}

# Extract all module files to look for depends
$mtemp = &tempname();
mkdir($mtemp, 0755);
foreach $d (@dirs) {
	system("cd $mtemp ; gunzip -c $dirs{$d} | tar xf - >/dev/null");
	local $testargs;
	if ($d =~ /^Net_SSLeay/) {
		$testargs = &has_command("openssl");
		$testargs =~ s/\/bin\/openssl$//;
		}
	local $cmd = "cd $mtemp/$d ; $perl_path Makefile.PL $testargs --skip";
	if (&foreign_check("proc")) {
		# Run in a PTY, to handle CPAN prompting
		&foreign_require("proc", "proc-lib.pl");
		local ($fh, $fpid) = &proc::pty_process_exec($cmd);
		&sysprint($fh, "no\n");    # For CPAN manual config question
		while(<$fh>) {
			# Wait till it completes
			}
		close($fh);
		}
	else {
		system("$cmd >/dev/null 2>&1 </dev/null");
		}
	local @prereqs;
	open(MAKEFILE, "$mtemp/$d/Makefile");
	while(<MAKEFILE>) {
		last if /MakeMaker post_initialize section/;
		if (/^#\s+PREREQ_PM\s+=>\s+(.+)/) {
			local $prereq = $1;
			while($prereq =~ m/(?:\s)([\w\:]+)=>q\[.*?\],?/g) {
				push(@prereqs, $1);
				}
			}
		}
	close(MAKEFILE);
	push(@allreqs, @prereqs);
	}
system("rm -rf $mtemp");

# Work out which pre-requesites are missing
@allreqs = &unique(@allreqs);
%needreqs = map { eval "use $_"; $@ ? ($_, 1) : ($_, 0) } @allreqs;
foreach $m (@mods) {
	# Don't need modules in tar files
	delete($needreqs{$m});
	}
foreach $c (@cpan) {
	# Don't need modules we are getting from CPAN
	delete($needreqs{$c});
	}

# Display install options
print "<p>\n";
print &ui_form_start("install.cgi");
print &ui_hidden("source", $in{'source'});
print &ui_hidden("need_unlink", $need_unlink);
foreach $pfile (@pfile) {
	print &ui_hidden("pfile", $pfile);
	}
foreach $m (@mods) {
	print &ui_hidden("mod", $m);
	}
foreach $v (@vers) {
	print &ui_hidden("ver", $v);
	}
foreach $d (@dirs) {
	print &ui_hidden("dir", $d);
	}
print &ui_hidden("return", $in{'return'});
print &ui_hidden("returndesc", $in{'returndesc'});
print &ui_table_start($text{'download_header'}, undef, 2);

# Modules being installed
for($i=0; $i<@mods; $i++) {
	$modmsg .= &html_escape($mods[$i])." ".&html_escape($vers[$i])."<br>\n";
	}
print &ui_table_row(@mods > 1 ? $text{'download_mods'} : $text{'download_mod'},
		    $modmsg);

# Missing modules
if (@missing) {
	print &ui_table_row($text{'download_missingok'},
			    join(" ", @missing));
	}

# Source
print &ui_table_row($text{'download_src'}, $source);

if (@allreqs) {
	# Pre-requisited
	@needreqs = grep { $needreqs{$_} } @allreqs;
	foreach $n (@needreqs) {
		print &ui_hidden("needreq", $n);
		}
	if (@needreqs) {
		$nmsg = " (".&text('download_missing', scalar(@needreqs)).")";
		}
	else {
		$nmsg = " ($text{'download_nomissing'})";
		}
	print &ui_table_row($text{'download_pres'},
	      join(" ", map { $needreqs{$_} ? "<i>$_</i>" : "<tt>$_</tt>" }
			    @allreqs).$nmsg);
	}

# Install mode
$in{'mode'} = 3 if ($in{'mode'} eq '');
print &ui_table_row($text{'download_act'},
	&ui_select("act", $in{'mode'},
		   [ [ 0, $text{'download_m'} ],
		     [ 1, $text{'download_mt'} ],
		     [ 2, $text{'download_mi'} ],
		     [ 3, $text{'download_mti'} ] ]));

# Command-line args to Makefile.PL
print &ui_table_row($text{'download_args'},
	&ui_textbox("args", $config{'def_args'}, 40));

# Table of environment variables
$etable = &ui_columns_start([ $text{'download_name'},
			      $text{'download_value'} ]);
for($i=0; $i<4; $i++) {
	$etable .= &ui_columns_row([ &ui_textbox("name_$i", undef, 15),
				     &ui_textbox("value_$i", undef, 30) ]);
	}
$etable .= &ui_columns_end();
print &ui_table_row($text{'download_envs'}, $etable);

print &ui_table_end();
print &ui_form_end([ [ undef, $text{'download_cont'} ],
		     @needreqs && $in{'source'} == 3 ?
			( [ "need", $text{'download_need'} ] ) : ( )
		   ]);

&ui_print_footer($in{'return'},
		 $in{'returndesc'} || $text{'index_return'});

sub install_error
{
print "<br><b>$main::whatfailed : $_[0]</b> <p>\n";
&ui_print_footer($in{'return'},
		 $in{'returndesc'} || $text{'index_return'});
exit;
}

