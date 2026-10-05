/* SPDX-License-Identifier: GPL-2.0 */
#ifndef MSDISP_DRM_COMPAT_H
#define MSDISP_DRM_COMPAT_H

#include <linux/version.h>

/* Linux 7.2 renamed the atomic transaction and its lifetime helpers. */
#if LINUX_VERSION_CODE >= KERNEL_VERSION(7, 2, 0)
#define drm_atomic_state       drm_atomic_commit
#define drm_atomic_state_alloc drm_atomic_commit_alloc
#define drm_atomic_state_clear drm_atomic_commit_clear
#define drm_atomic_state_put   drm_atomic_commit_put
#endif

#endif /* MSDISP_DRM_COMPAT_H */
