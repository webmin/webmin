# log_parser.pl
# Functions for parsing this module's logs

do 'apache-lib.pl';

# parse_webmin_log(user, script, action, type, object, &params)
# Converts logged information from this module into human-readable form
sub parse_webmin_log
{
local ($user, $script, $action, $type, $object, $p, $long) = @_;
local $typestr = "<i>".$text{"type_$type"}."</i>";
if ($action eq 'global') {
	return &text('log_global', $typestr);
	}
elsif ($action eq 'manual') {
	return &text('log_manual', "<tt>$p->{'file'}</tt>");
	}
elsif ($action eq 'virt') {
	$object = &html_escape($object);
	if ($type eq 'create') {
		return &text('log_virtc', "<tt>$object</tt>");
		}
	elsif ($type eq 'save') {
		return &text('log_virts', "<tt>$object</tt>");
		}
	elsif ($type eq 'delete') {
		return &text('log_virtd', "<tt>$object</tt>");
		}
	elsif ($type eq 'manual') {
		return &text('log_virtm', "<tt>$object</tt>");
		}
	else {
		return &text('log_virt', $typestr, "<tt>$object</tt>");
		}
	}
elsif ($action eq 'dir') {
	local ($virt, $dir);
	if ($object =~ /^([^:]+):(\d+):(.*)$/) {
		$virt = "$1:$2"; $dir = $3;
		}
	elsif ($object =~ /^([^:]+):(.*)$/) {
		$virt = $1; $dir = $2;
		}
	$virt = &html_escape($virt);
	$dir = &html_escape($dir);
	if ($type eq 'create') {
		return &text($long ? 'log_dirc_l' : 'log_dirc',
			     "<tt>$dir</tt>", "<tt>$virt</tt>");
		}
	elsif ($type eq 'save') {
		return &text($long ? 'log_dirs_l' : 'log_dirs',
			     "<tt>$dir</tt>", "<tt>$virt</tt>");
		}
	elsif ($type eq 'delete') {
		return &text($long ? 'log_dird_l' : 'log_dird',
			     "<tt>$dir</tt>", "<tt>$virt</tt>");
		}
	elsif ($type eq 'manual') {
		return &text($long ? 'log_dirm_l' : 'log_dirm',
			     "<tt>$dir</tt>", "<tt>$virt</tt>");
		}
	else {
		return &text($long ? 'log_dir_l' : 'log_dir', $typestr,
			     "<tt>$dir</tt>", "<tt>$virt</tt>");
		}
	}
elsif ($action eq 'htaccess') {
	$object = &html_escape($object);
	$virt = &html_escape($virt);
	if ($type eq 'create') {
		return &text('log_htaccessc',
			     "<tt>$object</tt>", "<tt>$virt</tt>");
		}
	elsif ($type eq 'delete') {
		return &text('log_htaccessd',
			     "<tt>$object</tt>", "<tt>$virt</tt>");
		}
	elsif ($type eq 'manual') {
		return &text('log_htaccessm',
			     "<tt>$object</tt>", "<tt>$virt</tt>");
		}
	else {
		return &text('log_htaccess', $typestr,
			     "<tt>$object</tt>", "<tt>$virt</tt>");
		}
	}
elsif ($action eq 'files') {
	local ($file, $path);
	if ($object =~ /^([^:]+):(.*)$/) {
		$file = $1; $path = $2;
		}
	$file = &html_escape($file);
	$path = &html_escape($path);
	if ($type eq 'create') {
		return &text($long ? 'log_filesc_l' : 'log_filesc',
			     "<tt>$path</tt>", "<tt>$file</tt>");
		}
	elsif ($type eq 'save') {
		return &text($long ? 'log_filess_l' : 'log_filess',
			     "<tt>$path</tt>", "<tt>$file</tt>");
		}
	elsif ($type eq 'delete') {
		return &text($long ? 'log_filesd_l' : 'log_filesd',
			     "<tt>$path</tt>", "<tt>$file</tt>");
		}
	elsif ($type eq 'manual') {
		return &text($long ? 'log_filesm_l' : 'log_filesm',
			     "<tt>$path</tt>", "<tt>$file</tt>");
		}
	else {
		return &text($long ? 'log_files_l' : 'log_files', $typestr,
			     "<tt>$path</tt>", "<tt>$file</tt>");
		}
	}
elsif ($action eq 'mime') {
	$object = &html_escape($object);
	return &text("log_mime_$type", "<tt>$object</tt>");
	}
elsif ($action eq 'defines') {
	return $text{'log_defines'};
	}
elsif ($action eq 'reconfig') {
	return $text{'log_reconfig'};
	}
elsif ($action eq 'mods') {
	return $text{'log_mods'};
	}
elsif ($action eq 'stop') {
	return $text{'log_stop'};
	}
elsif ($action eq 'start') {
	return $text{'log_start'};
	}
elsif ($action eq 'apply') {
	return $text{'log_apply'};
	}
elsif ($action eq 'virts') {
	return &text('log_virts_'.$type, $object);
	}
else {
	return undef;
	}
}

