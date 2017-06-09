#!/usr/local/bin/perl
# check_inst.cgi
# check majordomo options and installation

require './majordomo-lib.pl';
use Fcntl ':mode';

%access = &get_module_acl();
$conf = &get_config();

eval { require "$config{'program_dir'}/majordomo_version.pl"; };
&ui_print_header(undef, $text{'check_title'}, "", undef, 1, 1, 0,
        &mdom_help(),
        undef, undef, &text('index_version', $majordomo_version));

&check_mdom_config($conf);

$aliases_files = &get_aliases_file();
$email = &find_value("whoami", $conf); $email =~ s/\@.*$//g;
$owner = &find_value("whoami_owner", $conf); $owner =~ s/\@.*$//g;

# predefined values
local $cdiv='<div style="margin-left: 20%;">', $ediv='</div>';
local $ok="<div style=\"padding: .3em;\"><font color=\"green\">".&text('ok')."</font></div>";
local $fail="<div style=\"padding: .3em;\"><font color=\"red\">".&text('fail')."</font></div>";
local $res=$ok, $tocheck, $sec;

# init / start table 
local @tds;
push(@tds, "width=40%", "width=40%", "");
print &ui_columns_start([ &text('check_test'), &text('check_result'), &text('check_status')], 100, 0, \@tds);

# Check mailer / aliaes / config file
local $aliases=$aliases_files->[0], $mailer=$config{'aliases_file'};
$mailer="sendmail" if ($mailer eq '');
print &ui_columns_row(["<b>&nbsp; Autodetect aliases file from mailer</b>", ucfirst($mailer), $res], \@tds);
$res=$ok;
$tocheck=$aliases;
if (!-r $tocheck ) { $res=$fail; $tocheck .= " does not exist!"; }
print &ui_columns_row(["<b>&nbsp; Aliases file used for majordomo</b>", $tocheck, $res] , \@tds);
$res=$ok;
$tocheck=$config{'majordomo_cf'};
if (!-r $tocheck) { $res=$fail; $tocheck = &text('index_econfig', "<tt>$tocheck</tt>",
                 "$gconfig{'webprefix'}/config.cgi?$module_name"); }
print &ui_columns_row(["<b>&nbsp; Majordomo configuration file</b>", $tocheck, $res] , \@tds);

# config files exist?
if ( $res eq $ok) {
	# Check program dir / version
	$res=$ok;
	$tocheck=$config{'program_dir'};
	if (!-d $tocheck ) { $res=$fail; $tocheck = &text('index_eprograms', "<tt>$tocheck</tt>",
                  "$gconfig{'webprefix'}/config.cgi?$module_name"); }
	print &ui_columns_row(["<b>&nbsp; Majordomo programm dir</b>", $tocheck, $res] , \@tds);
	if ($res eq $ok) {
		$res="$cdiv $ok $edviv";
		$sec=$cdiv.&text('check_perm').$ediv;
		$tocheck=$config{'program_dir'};
		if (((stat($tocheck)) [2] & S_IXOTH) != 0) { $res=$fail; $sec .= ": world executable!"; }
		if (((stat($tocheck)) [2] & S_IROTH) != 0) { $res=$fail; $sec .= ": world readable!"; }
		if (((stat($tocheck)) [2] & S_IWOTH) != 0) { $res=$fail; $sec .= ": world writeable!"; }
		print &ui_columns_row(["", $sec, $res] , \@tds);
		$res=$ok;
		$tocheck=$majordomo_version;
		if ($tocheck eq "" || $tocheck < 1.94 || $tocheck >= 2) { $res=$fail; $tocheck .= ": ".$text{'index_eversion'}; }
		print &ui_columns_row(["<b>&nbsp; ".&text('index_version',"")."</b>", $tocheck, $res] , \@tds);
		}

	# Check home / list / archive dir from majordomo.cf
	$res=$ok;
	local $home=&find_value("homedir", $conf);
	$tocheck=$home;
	if (!&homedir_valid($conf)) { $res=$fail; $tocheck = &text('index_ehomedir', "<tt>$home</tt>"); }
	print &ui_columns_row(["<b>&nbsp; Majordomo HOME dir</b>", $tocheck, $res] , \@tds);
	$res="$cdiv $ok $edviv";
	$sec=$cdiv.&text('check_perm').$ediv;
	$tocheck=$home;
	if (((stat($tocheck)) [2] & S_IXOTH) != 0) { $res=$fail; $sec .= ": world executable!"; }
	if (((stat($tocheck)) [2] & S_IROTH) != 0) { $res=$fail; $sec .= ": world readable!"; }
	if (((stat($tocheck)) [2] & S_IWOTH) != 0) { $res=$fail; $sec .= ": world writeable!"; }
	print &ui_columns_row(["", $sec, $res] , \@tds);

	$res=$ok;
	$tocheck = &perl_var_replace(&find_value("listdir", $conf), $conf);
	if (!-d $tocheck) { $res=$fail; $tocheck = &text('index_elistdir', '$listdir', $tocheck); }
	print &ui_columns_row(["<b>&nbsp; Majordomo LIST directory</b>", $tocheck, $res] , \@tds);
	$tocheck = &perl_var_replace(&find_value("filedir", $conf), $conf);
	if (!-d $tocheck) { $res=$fail; $tocheck = &text('index_elistdir', '$filedir', $tocheck); }
	print &ui_columns_row(["<b>&nbsp; Majordomo ARCHIVE directory</b>", $tocheck, $res] , \@tds);
	}

print &ui_columns_end();

&ui_print_footer("/", $text{'index'});
irint&ui_columns_row(\@cols, \@tds);
