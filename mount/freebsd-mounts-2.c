#include <stdio.h>
#include <errno.h>
#include <sys/param.h>
#include <sys/ucred.h>
#include <sys/mount.h>

char *find_type(int t);
char *expand_flags(int f);

int main(void)
{
struct statfs *mntlist;
int n, i;

n = getmntinfo(&mntlist, MNT_NOWAIT);
if (n < 0) {
	fprintf(stderr, "getmntinfo failed : %s\n", strerror(errno));
	exit(1);
	}
for(i=0; i<n; i++) {
	printf("%s\t%s\t%s\t%s\t%x\n",
		mntlist[i].f_mntonname,
		mntlist[i].f_mntfromname,
		find_type(mntlist[i].f_type),
		expand_flags(mntlist[i].f_flags),
		mntlist[i].f_flags);
	}
return 0;
}

char *type_name[] = { "none", "ufs", "nfs", "mfs", "msdos", "lfs",
		      "lofs", "fdesc", "portal", "null", "umap", "kernfs",
		      "procfs", "afs", "cd9660", "union", "devfs", "ext2fs",
		      "tfs" };

char *find_type(int t)
{
if (t < 0 || t > 18) return "???";
else return type_name[t];
}

char *expand_flags(int f)
{
static char buf[1024];
buf[0] = 0;
if (f & MNT_RDONLY) strcat(buf, "ro,");
if (f & MNT_NOEXEC) strcat(buf, "noexec,");
if (f & MNT_NOSUID) strcat(buf, "nosuid,");
if (f & MNT_NOATIME) strcat(buf, "noatime,");
if (f & MNT_NODEV) strcat(buf, "nodev,");
if (f & MNT_SYNCHRONOUS) strcat(buf, "sync,");
if (f & MNT_ASYNC) strcat(buf, "async,");
if (f & MNT_QUOTA) strcat(buf, "quota,");
if (buf[0] == 0) return "-";
buf[strlen(buf)-1] = 0;
return buf;
}

