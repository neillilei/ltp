/*
 * Copyright (c) 2013 Fujitsu Ltd.
 * Author: DAN LI <li.dan@cn.fujitsu.com>
 *
 * This program is free software; you can redistribute it and/or modify it
 * under the terms of version 2 of the GNU General Public License as
 * published by the Free Software Foundation.
 *
 * This program is distributed in the hope that it would be useful, but
 * WITHOUT ANY WARRANTY; without even the implied warranty of
 * MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.
 *
 * You should have received a copy of the GNU General Public License along
 * with this program; if not, write the Free Software Foundation, Inc.,
 * 51 Franklin Street, Fifth Floor, Boston, MA 02110-1301 USA.
 */

/*
 * Test Name: quotactl02
 *
 * Description:
 * This testcase checks basic flags of quotactl(2) for an XFS file system:
 * 1) quotactl(2) succeeds to turn off xfs quota and get xfs quota off status.
 * 2) quotactl(2) succeeds to turn on xfs quota and get xfs quota on status.
 * 3) quotactl(2) succeeds to set and get xfs disk quota limits.
 */
#define _GNU_SOURCE
#include <errno.h>
#include <unistd.h>
#include <stdio.h>
#include <sys/quota.h>
#include "config.h"

#if defined(HAVE_QUOTAV2) || defined(HAVE_QUOTAV1)
# include <sys/quota.h>
#endif

#if defined(HAVE_XFS_QUOTA)
# include <xfs/xqm.h>
#endif

#include "tst_test.h"

#if defined(HAVE_XFS_QUOTA) && (defined(HAVE_QUOTAV2) || defined(HAVE_QUOTAV1))
static void check_qoff(char *);
static void check_qon(char *);
static void check_qlim(char *);

static int test_id;
static int mount_flag;
static struct fs_disk_quota set_dquota = {
	.d_rtb_softlimit = 1000,
	.d_fieldmask = FS_DQ_RTBSOFT
};
static unsigned short qflag = XFS_QUOTA_UDQ_ENFD;
static const char mntpoint[] = "mnt_point";

static struct t_case {
	int cmd;
	void *addr;
	void (*func_check)();
	char *des;
} tcases[] = {
	{QCMD(Q_XQUOTAOFF, USRQUOTA), &qflag, check_qoff,
	"turn off xfs quota and get xfs quota off status"},
	{QCMD(Q_XQUOTAON, USRQUOTA), &qflag, check_qon,
	"turn on xfs quota and get xfs quota on status"},
	{QCMD(Q_XSETQLIM, USRQUOTA), &set_dquota, check_qlim,
	"set and get xfs disk quota limits"},
};

static void check_qoff(char *desp)
{
	int res;
	struct fs_quota_stat res_qstat;

	res = quotactl(QCMD(Q_XGETQSTAT, USRQUOTA), tst_device->dev,
	               test_id, (void*) &res_qstat);
	if (res == -1) {
		tst_res(TFAIL | TERRNO,
			"quotactl() failed to get xfs quota off status");
		return;
	}

	if (res_qstat.qs_flags & XFS_QUOTA_UDQ_ENFD) {
		tst_res(TFAIL, "xfs quota enforcement was on unexpectedly");
		return;
	}

	tst_res(TPASS, "quoactl() succeeded to %s", desp);
}

static void check_qon(char *desp)
{
	int res;
	struct fs_quota_stat res_qstat;

	res = quotactl(QCMD(Q_XGETQSTAT, USRQUOTA), tst_device->dev,
	               test_id, (void*) &res_qstat);
	if (res == -1) {
		tst_res(TFAIL | TERRNO,
			"quotactl() failed to get xfs quota on status");
		return;
	}

	if (!(res_qstat.qs_flags & XFS_QUOTA_UDQ_ENFD)) {
		tst_res(TFAIL, "xfs quota enforcement was off unexpectedly");
		return;
	}

	tst_res(TPASS, "quoactl() succeeded to %s", desp);
}

static void check_qlim(char *desp)
{
	int res;
	static struct fs_disk_quota res_dquota;

	res_dquota.d_rtb_softlimit = 0;

	res = quotactl(QCMD(Q_XGETQUOTA, USRQUOTA), tst_device->dev,
	               test_id, (void*) &res_dquota);
	if (res == -1) {
		tst_res(TFAIL | TERRNO,
			"quotactl() failed to get xfs disk quota limits");
		return;
	}

	if (res_dquota.d_rtb_hardlimit != set_dquota.d_rtb_hardlimit) {
		tst_res(TFAIL, "quotactl() got unexpected rtb soft limit %llu,"
			" expected %llu", res_dquota.d_rtb_hardlimit,
			set_dquota.d_rtb_hardlimit);
		return;
	}

	tst_res(TPASS, "quoactl() succeeded to %s", desp);
}

static void setup(void)
{
	SAFE_MKDIR(mntpoint, 0755);

	SAFE_MKFS(tst_device->dev, "xfs", NULL, NULL);

	SAFE_MOUNT(tst_device->dev, mntpoint, "xfs", 0, "usrquota");
	mount_flag = 1;

	test_id = geteuid();
}

static void cleanup(void)
{
	if (mount_flag && tst_umount(mntpoint) < 0)
		tst_res(TWARN | TERRNO, "umount() failed");
}

static void verify_quota(unsigned int n)
{
	struct t_case *tc = &tcases[n];

	TEST(quotactl(tc->cmd, tst_device->dev, test_id, tc->addr));
	if (TEST_RETURN == -1) {
		tst_res(TFAIL | TTERRNO, "quotactl() failed to %s", tc->des);
		return;
	}

	tc->func_check(tc->des);
}

static struct tst_test test = {
	.tid = "quotactl02",
	.needs_tmpdir = 1,
	.needs_root = 1,
	.test = verify_quota,
	.tcnt = ARRAY_SIZE(tcases),
	.needs_device = 1,
	.setup = setup,
	.cleanup = cleanup
};
#else
	TST_TEST_TCONF("This system didn't support quota or xfs quota");
#endif
