# maketemp.pl
# Create the /tmp/.webmin directory if needed

$tmp_dir = $ENV{'tempdir'} || "/tmp/.webmin";

while($tries++ < 10) {
	local @st = lstat($tmp_dir);
	exit(0) if ($st[4] == $< && (-d _) && ($st[2] & 0777) == 0755);
	if (@st) {
		unlink($tmp_dir) || rmdir($tmp_dir) ||
			system("/bin/rm -rf ".quotemeta($tmp_dir));
		}
	mkdir($tmp_dir, 0755) || next;
	chown($<, $(, $tmp_dir);
	chmod(0755, $tmp_dir);
	}
exit(1);
