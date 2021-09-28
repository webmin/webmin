#!/usr/local/bin/perl
# check_inst.cgi
# check majordomo options and installation

require './majordomo-lib.pl';
use Fcntl ':mode';

%access = &get_module_acl();
$conf = &get_config();

eval { require "$config{'program_dir'}/majordomo_version.pl"; };
&ui_print_header(undef, $text{'check_title'}, "", undef, 1, 0, 0,
        &mdom_help(),
        undef, undef, &text('index_version', $majordomo_version));

$aliases_files = &get_aliases_file();
$email = &find_value("whoami", $conf); $email =~ s/\@.*$//g;
$owner = &find_value("whoami_owner", $conf); $owner =~ s/\@.*$//g;

# predefined values
local $cdiv='<div style="margin-left: 20%;">', $ediv='</div>';
local $ok="<div style=\"padding: .3em;\"><font color=\"green\">".&text('ok')."</font></div>";
local $fail="<div style=\"padding: .3em;\"><font color=\"red\">".&text('fail')."</font></div>";
local $possible="<div style=\"padding: .3em;\"><font color=\"orange\">".&text('check_possible')."</font></div>";
local $res=$ok, $tocheck, $sec;

# init / start table 
local @tds;
push(@tds,  "width=0", "width=30% nowrap", "width=60%", "");
print &ui_columns_start(["",&text('check_test'), &text('check_result'), &text('check_status')], 100, 0, \@tds);

# Check mailer / aliaes / config file
local $aliases=$aliases_files->[0], $mailer=$config{'aliases_file'};
$mailer="sendmail" if ($mailer eq '');
print &ui_checked_columns_row(["<b>Autodetect aliases file from mailer</b>", ucfirst($mailer), $res],
			 \@tds,undef, undef, 0,1);
$res=$ok;
$tocheck=$aliases;
if (!-r $tocheck) { $res=$fail; $tocheck = &text('index_esendmail', 'Sendmail alias file', $tocheck,
                  "@{[&get_webprefix()]}/config.cgi?$module_name"); }
print &ui_checked_columns_row(["<b>Aliases file used for majordomo</b>", $tocheck, $res],
			 \@tds,undef, undef, 0,1);
$res=$ok;
$tocheck=$config{'majordomo_cf'};
if (!-r $tocheck) { $res=$fail; $tocheck = &text('index_econfig', "<tt>$tocheck</tt>",
                 "@{[&get_webprefix()]}/config.cgi?$module_name"); }
print &ui_checked_columns_row(["<b>Majordomo configuration file</b>", $tocheck, $res],
			 \@tds,undef, undef, 0,1);

# config files exist?
if ( $res eq $ok) {
	# Check program dir / version
	$res=$ok;
	local $progdir, $progdirok;
	$tocheck= $progdir = $config{'program_dir'};
	if (!-d $tocheck ) { $res=$fail; $tocheck = &text('index_eprograms', "<tt>$tocheck</tt>",
                  "@{[&get_webprefix()]}/config.cgi?$module_name"); }
	print &ui_checked_columns_row(["<b>Majordomo programm dir</b>", $tocheck, $res],
			 \@tds,undef, undef, 0,1);
	if ($res eq $ok) {
		$progdirok=1;
		$res=$ok;
		$sec=$cdiv.&text('check_perm').":";
		$tocheck=$config{'program_dir'};
		if (((stat($tocheck)) [2] & S_IXOTH) != 0) { $res=$fail; $sec .= " ".&text('check_exec'); }
		if (((stat($tocheck)) [2] & S_IROTH) != 0) { $res=$fail; $sec .= " ".&text('check_read'); }
		if (((stat($tocheck)) [2] & S_IWOTH) != 0) { $res=$fail; $sec .= " ".&text('check_write'); }
		print &ui_checked_columns_row(["", $sec.$ediv, $res] , \@tds,undef, undef, 0,1);
		$res=$ok;
		$tocheck=$majordomo_version;
		if ($tocheck eq "" || $tocheck < 1.94 || $tocheck >= 2) { $res=$fail; $tocheck .= ": ".$text{'index_eversion'}; }
		print &ui_checked_columns_row(["<b>".&text('index_version',"")."</b>", $tocheck, $res],
				 \@tds,undef, undef, 0,1);
		}

	# Check home / list / archive dir from majordomo.cf
	$res=$ok;
	local $home=&find_value("homedir", $conf);
	$tocheck=$home;
	if ($tocheck ne $progdir) { $res=$fail; $tocheck = &text('index_emdomdir',
			 '$homedir'." (should be ".$progdir."!)", $tocheck); }
	print &ui_checked_columns_row(["<b>Majordomo script HOME dir</b>", $tocheck, $res],
			 \@tds,undef, undef, 0,1);
	$res=$ok;
	local $home=&find_value("homedir2", $conf);
	$tocheck=$home;
	if (! -d $tocheck) { $res=$fail; $tocheck = &text('index_emdomdir', '$homedir2', $home); }
	print &ui_checked_columns_row(["<b>Majordomo list HOME2 dir</b>", $tocheck, $res],
			 \@tds,undef, undef, 0,1);
	if ($res eq $ok) {
		$res=$ok;
		$sec=$cdiv.&text('check_perm').":";
		$tocheck=$home;
		if (((stat($tocheck)) [2] & S_IXOTH) != 0) { $res=$possible; $sec .= " ".&text('check_exec'); }
		if (((stat($tocheck)) [2] & S_IROTH) != 0) { $res=$possible; $sec .= " ".&text('check_read'); }
		if (((stat($tocheck)) [2] & S_IWOTH) != 0) { $res=$possible; $sec .= " ".&text('check_write'); }
		print &ui_checked_columns_row(["", $sec.$ediv, $res] , \@tds,undef, undef, 0,1);
		}
	$res=$ok;
	$tocheck = &perl_var_replace(&find_value("listdir", $conf), $conf);
	if (!-d $tocheck) { $res=$fail; $tocheck = &text('index_emdomdir', '$listdir', $tocheck); }
	print &ui_checked_columns_row(["<b>Majordomo LIST directory</b>", $tocheck, $res],
			 \@tds,undef, undef, 0,1);
	$res=$ok;
	$tocheck = &perl_var_replace(&find_value("filedir", $conf), $conf);
	if (!-d $tocheck) { $res=$fail; $tocheck = &text('index_emdomdir', '$filedir', $tocheck); }
	print &ui_checked_columns_row(["<b>Majordomo ARCHIVE directory</b>", $tocheck, $res],
			 \@tds,undef, undef, 0,1);
	# run wrapper config-test 
	if ($progdirok == 1) {
		local $cmd="$progdir/wrapper config-test";
		local $realcmd="cd $progdir; echo n | $cmd 2>&1";
		local $text=`$realcmd`;
		$text =~ s/(^|\n)[\n\s]*/$1/g;
		$text =~ s/Nothing bad found!.*/Nothing bad found!/s;
		if ($? != 0) {$res=$fail;}
		print &ui_checked_columns_row(["<b>Run Majormomo internal test</b>", $cmd, $res] ,
				\@tds,undef, undef, 0,1);
	        print &ui_checked_columns_row(["", "<pre>${text}</pre>", ""],
			 \@tds,undef, undef, 0,1);
		}
	}
print &ui_columns_end();

&ui_print_footer("index.cgi", $text{'index'});
