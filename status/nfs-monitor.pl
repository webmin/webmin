# nfs-monitor.pl
# Monitor the NFS server process

sub get_nfs_status
{
return { 'up' => -1 } if (!&foreign_check("proc"));
&foreign_require("proc", "proc-lib.pl");
if (&foreign_check("exports") || &foreign_check("dfsadmin") ||
    &foreign_check("bsdexports") || &foreign_check("hpuxexports")) {
	return { 'up' => &find_named_process('nfsd') ? 1 : 0 };
	}
else {
	return { 'up' => -1 };
	}
}

