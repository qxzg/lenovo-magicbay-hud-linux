# Lenovo MagicBay HUD on Arch Linux — worklog

日期：2026-07-11  
主机：Lenovo ThinkBook 14 G8+ IPH（Machine Type `21VG`）  
系统：Arch Linux、KDE Plasma / Wayland  
验证内核：`6.18.38-2-lts`、`7.1.3-arch1-2`、`7.1.3-zen1-2-zen`  
当前活动内核：`7.1.3-zen1-2-zen`  
工作目录：`/home/Azusa/Desktop/magicbay-hud-linux`

## 1. 最终结果

Lenovo MagicBay HUD 已经在 Arch Linux 中作为标准 DRM 扩展显示器工作，KWin 使用其原生模式 `1424×280 @ 60 Hz` 持续输出画面。

当前驱动已升级为第一阶段延迟优化版 `3.0.3.13-r2`。三个已安装内核均完成 DKMS 构建、签名和安装：

```text
magicbay-hud/3.0.3.13-r2, 6.18.38-2-lts, x86_64: installed
magicbay-hud/3.0.3.13-r2, 7.1.3-arch1-2, x86_64: installed
magicbay-hud/3.0.3.13-r2, 7.1.3-zen1-2-zen, x86_64: installed

/lib/modules/7.1.3-zen1-2-zen/updates/dkms/usbdisp_drm.ko.zst
/lib/modules/7.1.3-zen1-2-zen/updates/dkms/usbdisp_usb.ko.zst
```

稳定版 `3.0.3.13-r1` 的 `/usr/src` 源码与 DKMS 注册项继续保留，用于当前内核快速回退。

最终启动中的关键证据：

```text
usb 2-1: New USB device found, idVendor=17ef, idProduct=1117
[drm] Initialized msdisp 1.0.0 for msdisp_plat.0 on minor 1
usb 2-1: chip id:0x0 port:0x5 sdram:0x2
add mode:vic_174 1424x280@60 success
usbcore: registered new interface driver msdisp_usb
msdisp_plat msdisp_plat.0: enable: pid=839 comm=kwin_wayland
usb 2-1: pipe enable finished!
usb 2-1: start video success!
```

最终实时状态：

```text
/sys/class/drm/card1-HDMI-A-2/status: connected
/sys/class/drm/card1-HDMI-A-2/modes: 1424x280
USB interface 3 driver: msdisp_usb
```

已验证的完整链路：

1. HUD 在 USB 3.x 总线上枚举
2. `usbdisp_usb` 绑定 `17ef:1117` 的 vendor interface
3. HID Feature Report 完成芯片、EDID、模式和电源控制
4. DRM 驱动注册 connector、CRTC、plane 和 framebuffer
5. KWin 启用 `XR24` framebuffer 与 `1424×280@60` 模式
6. Bulk endpoint 4 开始传输显示帧
7. DKMS 在启动阶段自动加载两个模块

## 2. 硬件与协议识别

### 2.1 USB 设备

```text
VID:PID: 17ef:1117
Product: Lenovo MagicBay HUD
Manufacturer: Lenovo
bcdDevice: 31.00
USB speed: SuperSpeed 5 Gbps
```

HUD 在缺少主机协议初始化时会在枚举约 37 秒后从 USB 总线断开。适配后的驱动完成握手后，设备会保持在线。

### 2.2 USB 接口结构

| Interface | Class | Endpoint | 用途 |
|---|---:|---|---|
| `MI_00` | HID `03/00/00` | `0x81` Interrupt IN，64 bytes | HID 控制与状态 |
| `MI_01` | HID `03/00/00` | 控制端点 | HID Feature Report |
| `MI_02` | HID `03/00/00` | 控制端点 | HID Feature Report |
| `MI_03` | Vendor `ff/00/00` | `0x04` Bulk OUT，1024 bytes，MaxBurst 15 | 图像帧传输 |

设备级属性：

```text
bcdUSB: 3.20
bDeviceClass: 239 (Miscellaneous Device)
bDeviceSubClass: 2
bDeviceProtocol: 1 (Interface Association)
Bus powered: 512 mA
```

该布局与 MacroSilicon MS91xx Linux 驱动一致：HID Feature Report 承载寄存器、EDID、模式和电源控制，Bulk endpoint 4 承载显示帧。

## 3. 官方资料与社区研究

### 3.1 Lenovo 官方资料

- [Lenovo MagicBay HUD — Overview and Service Parts](https://pcsupport.lenovo.com/gp/en/accessories/ACC500406)
  - 官方规格：`1424×280 @ 60 Hz`
  - Windows 方案：Lenovo MagiCenter Solution `1.2.0.97`
  - 安装 MagiCenter 后重新连接 HUD，以完成识别与初始化
- [Lenovo MagicBay 接口开放指南](https://iknow.lenovo.com.cn/detail/435224)
  - MagicBay 提供 USB 3.x、USB 2.0、ID Detect 和 5 V 电源
  - HUD 属于 USB 3.0 高带宽模块
  - 最大持续供电能力为 `5 V / 3 A / 15 W`
  - ThinkBook 14 G8+ 系列位于适用主机列表

接口指南与 USB 描述符共同确认：HUD 通过 USB 传输显示数据。

### 3.2 Windows 驱动证据

Windows 系统分区 `/dev/nvme1n1p3` 曾通过 `udisksctl` 以只读方式挂载，分析结束后已完成卸载。

驱动存储路径：

```text
Windows/System32/DriverStore/FileRepository/
  msusbdisplaydriver.inf_amd64_07ba364825682ce6/
```

INF 关键字段：

```text
; MacroSilicon Usb Display Driver
Class = Display
DriverVer = 04/25/2025,4.1.12.27
Hardware ID = USB\VID_17EF&PID_1117&MI_03
UpperFilters = IndirectKmd
UmdfDispatcher = NativeUSB
UmdfExtensions = IddCx0102
ServiceBinary = msusbdisplaydriver.dll
```

Windows 使用 MacroSilicon UMDF2 间接显示驱动。`IddCx` 注册显示输出，厂商 DLL 通过 NativeUSB 控制 HUD 并传输帧。Windows 安装日志还记录了以下信息：

```text
Provider: Lenovo
Driver Version: 4.1.12.27
Signer: Microsoft Windows Hardware Compatibility Publisher
Target interface: USB\VID_17EF&PID_1117&MI_03
```

MagiCenter 是位于 `C:\Program Files\Lenovo\LenovoMagiCenter` 的 Electron 应用，负责 HUD 布局、组件、主题和场景功能；底层显示注册由 `msusbdisplaydriver.dll` 完成。

### 3.3 Linux 与社区项目

1. [MacroSilicon 官方 Linux 源码目录](http://www.macrosilicon.com:9080/download/USBDisplay/Linux/SourceCode/)

   本次采用的最新源码包：

   ```text
   MS91xx_Linux_Drm_SourceCode_V3.0.3.13.zip
   发布时间：2025-07-10
   包内目录：DRM_SourceCode_V3.0.3.12
   ```

2. [fathonix/ms9132-drm-linux](https://github.com/fathonix/ms9132-drm-linux)

   MacroSilicon 旧版 `V3.0.1.3` 源码镜像，代码结构与最新包一致。

3. [rhgndf/ms912x](https://github.com/rhgndf/ms912x)

   社区基于 Windows USB 抓包逆向的 DRM 驱动，记录了 HID 控制请求、YUV422 帧格式和 Bulk OUT 传输。

4. [Chendaqian/MagicCenterHub](https://github.com/Chendaqian/MagicCenterHub)

   Windows 项目，可把普通 WPF 窗口放到 HUD 的 `1424×280` 桌面区域。项目依赖 Lenovo/MacroSilicon 驱动完成底层显示注册。

## 4. 驱动方案

采用 MacroSilicon 官方 `MS91xx Linux DRM V3.0.3.13` 源码，主要能力包括：

- HID Feature Report 控制协议
- endpoint 4 Bulk 图像传输
- MS9132、MS9133、MS9135 协议族支持
- EDID 与详细时序读取
- `1424×280@60` 自定义模式注册
- 标准 DRM card/connector 输出

本目录加入 Lenovo HUD 硬件 ID：

```text
USB VID:PID = 17ef:1117
Interface class = ff/00/00
Module alias = usb:v17EFp1117d*dc*dsc*dp*icFFisc00ip00in*
```

相关文件：

```text
usb_hal/usb_device.h
usb_hal/usb_device.c
usb_hal/hal_adaptor.c
drm/ms9132_hal.c
drm/msdisp_usb_drv.c
```

## 5. 源码修改

### 5.1 Linux 7.1 DRM/API 适配

- `platform_driver.remove` 回调改为 `void`
- 清理已移除的 `drm_legacy.h` 依赖
- 加入 `linux/vmalloc.h`
- framebuffer 回调接收 `struct drm_format_info`
- `drm_helper_mode_fill_fb_struct()` 使用四参数形式
- 清理 `drm_driver.date` 字段
- 定时器容器使用 `timer_container_of()`
- 定时器删除使用 `timer_delete()`
- namespace import 使用字符串形式
- GEM mmap 路径适配当前 DRM 锁模型
- EDID 读取迁移到 `drm_edid_read_custom()`
- connector `mode_valid` 接收 const mode
- 加入 `linux/scatterlist.h`
- DRM file operations 加入 `FOP_UNSIGNED_OFFSET`

`FOP_UNSIGNED_OFFSET` 修复了 Linux 7.1 `drm_open_helper()` 的校验警告：

```text
!(filp->f_op->fop_flags & FOP_UNSIGNED_OFFSET)
WARNING: drivers/gpu/drm/drm_file.c:329 at drm_open_helper
```

### 5.2 HUD 专用显示修正

- `mode_config.min_width/min_height` 从 `640×480` 调整为 `1×1`
- 初始 pipeline 数量从 3 调整为 1
- HUD 只注册一个 connector/CRTC/plane 组合

`1424×280` 的高度低于上游驱动原有 `min_height=480`，KWin 创建 framebuffer 时会得到 `EINVAL`。调整尺寸下限后，KWin 成功启用 `XR24` framebuffer：

```text
format: 0x34325258 (XR24)
width: 1424
height: 280
pitch: 5888
```

### 5.3 内存与生命周期修正

- USB 图像传输直接使用上游已有的 vmalloc + scatter-gather 路径
- 跳过 8 MiB `usb_alloc_coherent()` 高阶连续页分配
- 清理 platform device 中栈上 `struct dev_iommu` 指针的临时赋值

这些修改消除了首次加载中的高阶页分配警告，并修复模块卸载时的 `iommu_bus_notifier` Oops。

首次 Oops 的关键记录：

```text
BUG: unable to handle page fault
RIP: iommu_bus_notifier+0xbb/0x180
msdisp_platform_remove_all_devices
msdisp_exit
```

根因是 platform device 保存了指向栈上 `struct dev_iommu` 的悬空指针。当前 `msdisp_plat_dev.c` 由内核设备模型管理 platform device 生命周期。

### 5.4 日志降噪

上游驱动会在每次 framebuffer 创建时调用 `dev_info()`，实测十分钟产生 97 条 `fb id:` 记录。当前版本改用 `dev_dbg()`。最终重启后：

```text
fb-info-count=0
```

## 6. DKMS 与开机自动加载

### 6.1 DKMS 配置

配置文件：[dkms.conf](./dkms.conf)

```text
PACKAGE_NAME="magicbay-hud"
PACKAGE_VERSION="3.0.3.13-r2"
AUTOINSTALL="yes"
```

版本格式为 `<基础代码版本>-r<本地修订号>`：

- `3.0.3.13` 表示 MacroSilicon 基础代码版本
- `r1` 表示首个 MagicBay HUD 稳定修订
- `r2` 表示第一阶段延迟优化修订
- `dkms.conf` 是发布版本的唯一来源，Make/Kbuild 将同一版本注入 `usbdisp_drm` 与 `usbdisp_usb`
- DRM core 的 `1.0.0` 单独表示 DRM ABI，通过 `DRM_ABI_MAJOR/MINOR/PATCH` 管理

历史开发名 `lenovo1` 与 `lenovo2` 分别映射为 `r1` 与 `r2`。

自 `r3` 起版本格式改为 `<基础代码版本>.r<本地修订号>`（例如 `3.0.3.13.r3`）。Arch 的 DKMS pacman hook（`/usr/share/libalpm/scripts/dkms`）用 `^/usr/src/([^/]+)-([^/]+)/dkms.conf$` 拆分模块名与版本，在最后一个 `-` 处切开；`3.0.3.13-r2` 因此在内核升级时被注册为模块 `magicbay-hud-3.0.3.13`、版本 `r2`，导致 `dkms status -m magicbay-hud` 与 `dkms remove magicbay-hud/3.0.3.13-r2` 均无法匹配。`PACKAGE_VERSION` 不得包含 `-`。

源码安装位置：

```text
/usr/src/magicbay-hud-3.0.3.13-r2
```

DKMS 构建命令使用 `env -u KERNELRELEASE`。该处理保证顶层 Makefile 进入外部模块构建入口，随后由 `drm/Makefile` 调用当前内核的 Kbuild。

当前安装状态：

```bash
dkms status -m magicbay-hud
```

```text
magicbay-hud/3.0.3.13-r1, 6.18.38-2-lts, x86_64: built
magicbay-hud/3.0.3.13-r1, 7.1.3-arch1-2, x86_64: built
magicbay-hud/3.0.3.13-r1, 7.1.3-zen1-2-zen, x86_64: built
magicbay-hud/3.0.3.13-r2, 6.18.38-2-lts, x86_64: installed
magicbay-hud/3.0.3.13-r2, 7.1.3-arch1-2, x86_64: installed
magicbay-hud/3.0.3.13-r2, 7.1.3-zen1-2-zen, x86_64: installed
```

旧开发名 `lenovo1/lenovo2` 的 DKMS 注册项与源码目录已在 `r1/r2` 验证完成后清理。

### 6.2 自动加载

配置文件：

```text
/etc/modules-load.d/magicbay-hud.conf
```

内容：

```text
usbdisp_drm
usbdisp_usb
```

`usbdisp_usb` 通过模块依赖引用 `usbdisp_drm`。显式列出两个模块可以在 HUD 晚于系统启动吸附时提前准备 DRM 设备和 USB 驱动。

### 6.3 DKMS 签名

两个安装模块均由本地 DKMS key 签名：

```text
signer: DKMS module signing key
```

当前内核未信任该本地 key，因此启动日志记录：

```text
module verification failed: signature and/or required key missing
loading out-of-tree module taints kernel
```

该状态会标记 out-of-tree/module-signature taint。显示、热插拔与重启验证均正常完成。

## 7. 编译与安装

### 7.1 本地编译

```bash
cd /home/Azusa/Desktop/magicbay-hud-linux
make -j4
```

输出模块：

```text
drm/usbdisp_drm.ko
drm/usbdisp_usb.ko
```

### 7.2 当前 DKMS 安装流程

```bash
sudo cp -a \
  /home/Azusa/Desktop/magicbay-hud-linux \
  /usr/src/magicbay-hud-3.0.3.13-r2

sudo dkms add -m magicbay-hud -v 3.0.3.13-r2

for kernel in 6.18.38-2-lts 7.1.3-arch1-2 7.1.3-zen1-2-zen; do
  sudo dkms install \
    -m magicbay-hud \
    -v 3.0.3.13-r2 \
    -k "$kernel" \
    --force
done
```

自动加载配置通过以下命令安装：

```bash
sudo install -m 0644 \
  /tmp/magicbay-hud.modules-load.conf \
  /etc/modules-load.d/magicbay-hud.conf
```

`/tmp/magicbay-hud.modules-load.conf` 的内容就是 `usbdisp_drm` 与 `usbdisp_usb` 两行。

### 7.3 源码更新后的重建

同一版本源码发生变化时，先把最终源码同步到已注册目录，再强制重建三个内核：

```bash
sudo cp -- dkms.conf WORKLOG.md \
  /usr/src/magicbay-hud-3.0.3.13-r2/
sudo cp -- drm/*.c drm/*.h \
  /usr/src/magicbay-hud-3.0.3.13-r2/drm/

for kernel in 6.18.38-2-lts 7.1.3-arch1-2 7.1.3-zen1-2-zen; do
  sudo dkms build \
    -m magicbay-hud \
    -v 3.0.3.13-r2 \
    -k "$kernel" \
    --force
  sudo dkms install \
    -m magicbay-hud \
    -v 3.0.3.13-r2 \
    -k "$kernel" \
    --force
done
```

驱动版本升级时应同步更新 `dkms.conf` 中的 `PACKAGE_VERSION` 与 `/usr/src` 目录名。

### 7.4 当前内核回退到 r1

为当前内核强制安装保留的稳定版本：

```bash
sudo dkms install \
  -m magicbay-hud \
  -v 3.0.3.13-r1 \
  -k "$(uname -r)" \
  --force
sudo depmod -a "$(uname -r)"
```

运行中的 DRM 模块保持加载，版本切换通过正常系统重启生效。回到 `r2` 时把 DKMS 安装命令中的版本改为 `3.0.3.13-r2`，完成安装后正常重启。

## 8. 验证命令

### 8.1 USB 与模块

```bash
lsusb -v -d 17ef:1117
usb-devices | sed -n '/Vendor=17ef ProdID=1117/,/^$/p'
lsmod | rg '^usbdisp_(drm|usb)'
modinfo -n usbdisp_drm
modinfo -n usbdisp_usb
modinfo -F alias usbdisp_usb | rg '17EF.*1117'
```

### 8.2 DRM 输出

```bash
cat /sys/class/drm/card1-HDMI-A-2/status
head -n 1 /sys/class/drm/card1-HDMI-A-2/modes
kscreen-doctor -o
```

预期结果：

```text
connected
1424x280
```

### 8.3 启动日志

```bash
journalctl -k -b --no-pager \
  | rg 'usbdisp|msdisp|chip id|add mode|start video|Oops|BUG:'
```

关键成功标志：

```text
Initialized msdisp
chip id:0x0 port:0x5 sdram:0x2
add mode:vic_174 1424x280@60 success
pipe enable finished
start video success
```

## 9. 已验证范围与维护边界

已验证：

- `linux-lts 6.18.38-2-lts` 编译与 DKMS 安装
- `linux 7.1.3-arch1-2` 编译与 DKMS 安装
- `linux-zen 7.1.3-zen1-2-zen` 编译、DKMS 安装与正常启动
- KDE Plasma / Wayland / KWin
- 启动后吸附与启动时吸附
- USB 重新吸附后的设备绑定
- `1424×280@60` 原生模式
- DKMS 编译、签名、安装与开机自动加载
- 完整重启后的自动恢复
- framebuffer 日志降噪

后续兼容性项目：

- 三个内核的实际启动验证
- 系统休眠与唤醒循环
- 长时间视频与高刷新内容稳定性
- Plasma 输出布局在不同缩放比例下的恢复行为
- 将 Lenovo `17ef:1117` 与 Linux 7.1 补丁整理为上游提交

当前源码基于厂商 out-of-tree DRM 驱动，Linux 内核 API 更新可能触发新的编译适配工作。DKMS 会在内核升级时执行自动重建；升级后通过 `dkms status -m magicbay-hud` 与启动日志确认结果。

## 10. 延迟诊断与优化路线

补充日期：2026-07-13

HUD 已经稳定输出画面，实际交互仍能感受到明显延迟。源码检查与实时统计定位出两个高优先级时序问题，以及若干后续性能优化点。

### 10.1 实时传输数据

当前 USB 链路与 framebuffer 参数：

```text
USB speed: 5000 Mbps
USB buffer type: vmalloc + scatter-gather
Full YUV422 frame: 797456 bytes
Mode: 1424×280 @ 60 Hz
```

完整帧按 60 fps 计算约为：

```text
797456 × 60 = 47847360 bytes/s
约 47.8 MB/s，约 383 Mbps
```

该吞吐量在 5 Gbps USB 3.x 链路能力范围内。诊断期间 `try lock fail` 保持为 0，内核日志也未记录 `wait urb failed`、`send frame Elapsed` 或 `send zero msg failed`。USB 带宽与传输错误的排查优先级较低。

### 10.2 `atomic_update` 上一帧诊断与修复

`r1` 的 `drm/msdisp_drm_modeset.c` 在 Linux 5.13+ 路径获取旧 plane state：

```c
struct drm_plane_state *old_state =
    drm_atomic_get_old_plane_state(atom_state, plane);

fb = old_state->fb;
```

DRM atomic helper 在提交前已经把新状态交换到当前对象，传入的 `atom_state` 保存旧状态用于资源清理。该代码因此把上一帧 framebuffer 交给 USB 路径。

相关内核文档：

- [Linux DRM Mode Setting Helper Functions](https://docs.kernel.org/gpu/drm-kms-helpers.html)
- [Linux DRM Atomic State API](https://docs.kernel.org/gpu/drm-kms.html)

在 60 Hz 下，单帧周期约为 `16.67 ms`。该问题会稳定增加至少一个帧周期，并可能与 KWin 的提交队列和 HUD 内部缓冲继续叠加。

`r2` 读取新 plane state：

```c
struct drm_plane_state *new_state =
    drm_atomic_get_new_plane_state(atom_state, plane);

fb = new_state->fb;
```

新状态提供本次提交需要显示的 framebuffer。Linux 5.12 及更早分支读取已经交换完成的 `plane->state`。

### 10.3 60 Hz hrtimer vblank

`r1` 的 `drm/msdisp_drm_drv.c` 固定使用：

```c
#define MSDISP_DRM_VBLANK_TIMER_OUT_MS 20
```

定时器每 20 ms 执行：

```c
drm_crtc_handle_vblank(crtc);
msdisp_drm_handle_page_flip(&msdisp->pipeline[i]);
```

20 ms 对应 50 Hz，HUD 的 EDID 模式为 60 Hz，对应约 16.667 ms。page-flip 完成事件因此按照约 50 Hz 返回给 KWin，形成帧节奏偏差和额外等待。

`r2` 为每个 pipeline 配置独立 `hrtimer`：

1. `atomic_enable` 根据 `drm_mode_vrefresh()` 计算纳秒周期
2. 60 Hz 使用 `NSEC_PER_SEC / 60 = 16666666 ns`
3. refresh rate 为 0 时采用 60 Hz 回退值并记录警告
4. 回调使用 `hrtimer_forward_now()` 与 `HRTIMER_RESTART`
5. `atomic_disable` 完成待处理 page-flip event 并取消对应 timer
6. inactive CRTC 设置 `no_vblank`，使 atomic helper 直接完成 disable commit

Linux 6.13+ 使用 `hrtimer_setup()`；早期内核使用 `hrtimer_init()` 和回调赋值。API 分界参考 [Linux 6.12 hrtimer.h](https://github.com/torvalds/linux/blob/v6.12/include/linux/hrtimer.h)、[Linux 6.13 hrtimer.h](https://github.com/torvalds/linux/blob/v6.13/include/linux/hrtimer.h) 与 [hrtimer 文档](https://docs.kernel.org/next/driver-api/basics.html)。

长期实现还应让 page-flip 完成时机与 USB 帧提交保持关联，使 KWin 获得更接近实际传输进度的反馈。

### 10.4 CPU 复制、变化检测与颜色转换

当前每次 DRM 更新经过以下路径：

1. 在 `usb_hal_update_frame()` 中把 XRGB8888 framebuffer 复制到 `desktop_buf`
2. 在 `usb_hal_update_change_rects()` 中比较新旧完整 framebuffer，计算变化矩形
3. 在 `usb_hal_image_to_yuv()` 中逐像素执行 XRGB8888 → YUV422 转换
4. 把变化矩形封装后提交同步 Bulk URB
5. 等待 URB 完成并发送 zero-length packet

`update_frame()` 与发送线程通过同一个 `usb_buf.mutex` 串行。大面积动画、窗口拖动和视频播放会扩大变化矩形，使比较、复制和颜色转换占用更多时间。

当前事件线程会一次取出 FIFO 中积累的 update 事件，并把它们合并为一次最新画面发送。该行为可以限制队列深度；共享 framebuffer 与互斥锁仍会让 compositor 提交路径等待发送线程完成转换阶段。

后续优化方向：

- 使用 DRM framebuffer damage clips 直接获得变化区域
- 把变化矩形传入 USB HAL，减少完整 framebuffer 扫描
- 为 `desktop_buf` 建立双缓冲或 latest-frame slot
- 让 KWin 提交路径完成快速复制后立即返回
- 在后台工作线程执行变化检测、YUV422 转换和 URB 提交
- 为鼠标移动保留小矩形快速路径

### 10.5 HUD 内部缓冲

MacroSilicon 芯片报告 `sdram type:0x2`，驱动维护两个 frame rect/index，并在发送后切换 `frame_index`。该结构表明 HUD 固件内部存在 SDRAM 与双缓冲处理。USB URB 完成到面板开始扫描之间可能再增加一个帧周期；这一项需要通过外部高速摄影测量。

### 10.6 优化实施顺序

第一阶段已经完成两个确定性时序修复：

1. `old_state->fb` 改为 `new_state->fb`
2. vblank 从固定 20 ms 改为与 60 Hz 对齐的周期
3. DKMS 包版本递增，保留当前稳定版本用于回退
4. 通过正常重启验证 KWin 输出和内核日志

第二阶段优化帧处理路径：

1. 接入 DRM damage clips
2. 引入 latest-frame 双缓冲
3. 把 CPU 转换和 USB 发送移出 atomic commit 热路径
4. 调整 page-flip completion 与 USB 提交时序
5. 优化 cursor-only 更新

### 10.7 延迟验证方法

使用手机 120 fps 或 240 fps 慢动作同时拍摄内屏和 HUD：

1. 把同一个高对比度方块横跨两个输出移动
2. 逐帧统计内屏变化到 HUD 变化之间的帧数
3. 分别记录静态鼠标、窗口拖动、全屏动画和视频播放
4. 每个驱动版本重复同一组测试三次

同时采集：

```bash
cat /sys/devices/usbevdi/msdisp_plat.0/pipeline0/frame
cat /sys/bus/usb/devices/2-1:1.3/frame
journalctl -k -b --no-pager \
  | rg 'usbdisp|msdisp|Elapsed|wait urb|BUG:|Oops'
```

第一阶段的高速摄影目标是中位延迟减少至少一个 framebuffer 周期，并让 KWin 的 page-flip pacing 与 60 Hz 模式一致。第二阶段目标是降低大面积动态内容中的提交等待和帧处理时间。

### 10.8 第一阶段实现与构建结果

正式版本：

```text
DKMS package: 3.0.3.13-r2
usbdisp_drm module: 3.0.3.13-r2
usbdisp_usb module: 3.0.3.13-r2
DRM ABI: 1.0.0
```

实现内容：

- `atomic_update` 发送本次 atomic commit 的新 framebuffer
- 统计字段与 sysfs 文本使用 `no new state`
- 每个 pipeline 持有独立 `hrtimer`、`vblank_period` 与原子 `vblank_count`
- pipeline `info` 提供 `vblank period ns` 和 `vblank count`
- device remove 逐 pipeline 取消 timer
- device remove 同步结束 DRM connector polling
- inactive CRTC 通过 `no_vblank` 跳过 disable commit 的收尾等待

三个内核均生成两个 `.ko`。编译警告集合保持为厂商源码既有的 missing-prototypes 与 missing MODULE_DESCRIPTION 基线。

### 10.9 第一阶段验收记录

DKMS 与当前模块：

```text
6.18.38-2-lts: installed, signed, usbdisp_drm 3.0.3.13-r2
7.1.3-arch1-2: installed, signed, usbdisp_drm 3.0.3.13-r2
7.1.3-zen1-2-zen: installed, signed, usbdisp_drm 3.0.3.13-r2
r1 rollback package: built and signed for all three kernels
```

2026-07-13 23:22 的功能验证使用统一命名前的模块元数据：

```text
loaded usbdisp_drm: 1.0.2
loaded usbdisp_usb: 1.1.0
connector: connected
mode: 1424x280 @ 60 Hz
vblank period ns: 16666666
10 s vblank delta: 600
10 s handle fail delta: 0
10 s state error delta: 0
10 s try lock fail delta: 0
no new state: 0
```

2026-07-14 已将三个内核的安装模块统一为 `3.0.3.13-r2`。当前会话继续运行启动时加载的旧元数据，下一次正常重启将加载统一版本。

KWin 自动启用 HUD，当前启动中的 MagicBay Oops、BUG、vblank wait 和 URB 错误扫描为空。实际交互体感显示延迟明显改善。

上一启动中的强制模块卸载触发了 DRM polling Oops，持有 DRM client 时解绑平台设备造成桌面冻结。版本切换流程已经固定为 DKMS 安装后正常重启。

2026-07-14 完成两轮物理拔插。每轮重新吸附后均恢复 `connected`、`1424×280@60`、`pipe enable finished` 与 `start video success`。两次分离后的日志均未出现 vblank timeout、Oops、BUG 或 URB 错误。

30 秒鼠标、窗口拖动和动态内容采样：

```text
vblank delta: 1800
frame total delta: 1414
send total delta: 1415
send success delta: 505
handle fail delta: 0
state error delta: 0
try lock fail delta: 0
no new state: 0
```

拔插窗口累计产生 `no usb hal: 5` 与 `handle fail: 2`，两次重新吸附后的活动采样增量均为 0。120/240 fps 高速摄影继续作为正式量化延迟对比项目。

## 11. 结论

Lenovo MagicBay HUD 的显示控制器属于 MacroSilicon MS91xx USB Display 系列。Windows 的 Lenovo/MacroSilicon IddCx 驱动与 Linux 官方 DRM 源码使用相同的 HID 控制加 Bulk 图像传输结构。

加入 Lenovo `17ef:1117`、Linux 7.1 API 适配、280 像素高度支持、单 pipeline、IOMMU 生命周期修正、vmalloc 传输路径、当前 framebuffer 提交与 60 Hz hrtimer pacing 后，HUD 已经成为 Arch Linux/KWin 中可启动、可热插拔、可随内核升级重建的标准扩展显示器。
