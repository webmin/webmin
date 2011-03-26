#!/usr/bin/perl
# Export all matching logs in WELF format

require './itsecur-lib.pl';
&can_edit_error("report");
use POSIX;
&ReadParse();

@logs = &parse_all_logs();
@logs = &filter_logs(\@logs, \%in, \@searchvars);
if ($in{'save_name'}) {
	push(@searchvars, "save_name=".&urlize($in{'save_name'}));
	}

# Build map of protos and ports to services
@servs = &list_services();
foreach $s (@servs) {
	for($i=0; $i<@{$s->{'protos'}}; $i++) {
		$proto = lc($s->{'protos'}->[$i]);
		$port = $s->{'ports'}->[$i];
		if ($port =~ /^(\d+)\-(\d+)$/) {
			foreach $p ($1 .. $2) {
				$multi_map{$proto,$p} = $s;
				}
			}
		else {
			$serv_map{$proto,$port} = $s;
			}
		}
	}

# Validate inputs
&error_setup($text{'welf_err'});
if ($in{'dest_mode'} == 1) {
	$orig_dest = $in{'dest'};
	if (-d $in{'dest'}) {
		$in{'dest'} .= "/logs.welf";
		}
	$in{'dest'} =~ /^(.*)\// || &error($text{'backup_edest'});
	-d $1 || &error($text{'backup_edestdir'});
	$file = $in{'dest'};
	$done = &text('welf_done1', $file);
	}
elsif ($in{'dest_mode'} == 2) {
	gethostbyname($in{'ftphost'}) || &error($text{'backup_eftphost'});
	$in{'ftpfile'} =~ /^\/\S+/ || &error($text{'backup_eftpfile'});
	$in{'ftpuser'} =~ /\S/ || &error($text{'backup_eftpuser'});
	$file = "ftp://$in{'ftpuser'}:$in{'ftppass'}\@$in{'ftphost'}$in{'ftpfile'}";
	$done = &text('welf_done2', $in{'ftphost'}, $in{'ftpfile'});
	}
elsif ($in{'dest_mode'} == 3) {
	$in{'email'} =~ /^\S+\@\S+$/ || &error($text{'backup_eemail'});
	$file = "mailto:$in{'email'}";
	$done = &text('welf_done3', $in{'email'});
	}

$temp = &tempname();
open(OUT, ">$temp") || &error($!);
$host = &get_system_hostname();
foreach $l (reverse(@logs)) {
	print OUT "id=firewall ";
	@tm = localtime($l->{'time'});
	print OUT "time=\"",strftime("%Y-%m-%d %H:%M:%S", @tm),"\" ";
	print OUT "fw=$host ";
	if (&deny_action($l)) {
		print OUT "pri=4 ";
		}
	else {
		print OUT "pri=5 ";
		}
	print OUT "rule=$l->{'rule'} ";
	if ($l->{'proto'} && $l->{'dst_port'}) {
		# Find the service name
		local $serv = $serv_map{lc($l->{'proto'}),$l->{'dst_port'}} ||
			      $multi_map{lc($l->{'proto'}),$l->{'dst_port'}};
		if ($serv) {
			print OUT "proto=$serv->{'name'} ";
			}
		}
	print OUT "src=$l->{'src'} ";
	print OUT "dst=$l->{'dst'}\n";
	}
close(OUT);

# Send to destination
($mode, @dest) = &parse_backup_dest($file);
if ($mode == 1) {
	# Move to destination
	$out = `mv '$temp' '$file' 2>&1`;
	&error($out) if ($?);
	}
elsif ($mode == 2) {
	# FTP somewhere
	local $err;
	&ftp_upload($dest[2], $dest[3], $temp, \$err, undef, $dest[0], $dest[1]);
	unlink($temp);
	&error($err) if ($err);
	}
elsif ($mode == 3) {
	# Email somewhere
	$data = `cat $temp`;
	unlink($temp);
	$host = &get_system_hostname();
	$body = "Firewall logs in WELF format from $host are attached to this email.\n";
	local $mail = { 'headers' =>
			[ [ 'From', $config{'from'} || "webmin\@$host" ],
			  [ 'To', $dest[0] ],
			  [ 'Subject', "Firewall logs" ] ],
			'attach' =>
			[ { 'headers' => [ [ 'Content-type', 'text/plain' ] ],
			    'data' => $body },
			  { 'headers' => [ [ 'Content-type', 'text/plain' ] ],
			    'data' => $data } ] };
	$main::errors_must_die = 1;
	if (&foreign_check("mailboxes")) {
		&foreign_require("mailboxes", "mailboxes-lib.pl");
		eval { &mailboxes::send_mail($mail); };
		}
	else {
		&foreign_require("sendmail", "sendmail-lib.pl");
		&foreign_require("sendmail", "boxes-lib.pl");
		eval { &sendmail::send_mail($mail); };
		}
	return $@ if ($@);
	}

# Save settings
$config{'welf_dest'} = $in{'dest_mode'} == 0 ? undef : $file;
&write_file($module_config_file, \%config);

if ($in{'dest_mode'} == 0) {
	# Send to browser
	print "Content-type: text/plain\n\n";
	open(FILE, $temp);
	while(<FILE>) {
		print;
		}
	close(FILE);
	unlink($temp);
	&remote_webmin_log("backup");
	}
else {
	# Tell the user
	&header($text{'welf_title'}, "",
		undef, undef, undef, undef, &apply_button());
	print "<hr>\n";

	print "<p>$done<p>\n";

	print "<hr>\n";
	&footer("/$module_name/list_report.cgi?".join("&", @searchvars),
		$text{'report_return'});
	}

