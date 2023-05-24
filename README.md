
# ArvanCloud Network Bench Script

![ArvanCloud Logo](.github/logo.svg)


This script automates the execution to collect data's that our support team needs to troubleshoot your cloud server network, Included are several tests to check the performance of network of a server: Network performance with iperf3 & MTR.


## How to Run

```bash
bash <(curl -s https://raw.githubusercontent.com/arvancloud/support/main/bench.sh)
```

or 

```bash
bash <(wget -qO- https://raw.githubusercontent.com/arvancloud/support/main/bench.sh)
```
This script has been tested on the following Linux distributions:
* CentOS 6+
* Debian 8+
* Fedora 30
* Ubuntu 16.04+

#### Notes
* Local iperf3 Package: If the tested system has iperf3 already installed, the local package will take precedence over the precompiled binary.

* Experimental ARM Compatibility: Initial ARM compatibility has been introduced, however, is not considered entirely stable due to limited testing on distinct ARM devices. Report any errors or issues.

* High Bandwidth Usage Notice: By default, this script will perform many iperf network tests, which will try to max out the network port for ~20s per location (10s in each direction).

## Security Notice

This script relies on external binaries in order to complete the performance tests. The network iperf3 tests used binaries that are compiled to ensure binary portability. The reasons for doing this include ensuring standardized (parsable) output, allowing support of both 32-bit and 64-bit architectures, bypassing the need for prerequisites to be compiled and/or installed, among other reasons. Use this script at your own risk as you would with any script publicly available on the net.

# اسکریپت بنچ مارک ابرآروان

این اسکریپت، تست هایی را به صورت خودکار انجام میدهد تا داده‌هایی که تیم پشتیبانی ما برای رفع مشکلات شبکه سرور ابری شما نیاز دارد، جمع‌آوری کند. در این اسکریپت چندین آزمون برای بررسی عملکرد شبکه سرور وجود دارد: تست عملکرد شبکه با استفاده از iperf3 و MTR.

## نحوه اجرا

```bash
bash <(curl -s https://raw.githubusercontent.com/arvancloud/support/main/bench.sh)
```

یا

```bash
bash <(wget -qO- https://raw.githubusercontent.com/arvancloud/support/main/bench.sh)
```
این اسکریپت بر روی توزیع‌های لینوکس زیر آزمایش شده است
* CentOS 6+
* Debian 8+
* Fedora 30
* Ubuntu 16.04+


#### نکات
<ul>
  <li>بسته محلی iperf3: در صورتی که سیستم آزمایشی قبلاً iperf3 را نصب کرده باشد، بسته محلی در اولویت قرار خواهد گرفت و جایگزین باینری قبلی خواهد شد.</li>
  <li>سازگاری ARM آزمایشی: سازگاری اولیه با ARM معرفی شده است، اما به دلیل تست محدود در دستگاه‌های متفاوت ARM، به عنوان کاملاً پایدار در نظر گرفته نمی‌شود. هرگونه خطا یا مشکل را گزارش دهید.</li>
  <li>هشدار مصرف پهنای باند بالا: به طور پیش فرض، این اسکریپت تست‌های شبکه iperf زیادی را انجام می‌دهد که تلاش می‌کند تا پورت شبکه را به مدت تقریبی 20 ثانیه در هر مکان (10 ثانیه به هر سرور) به حداکثر برساند.</li>
</ul>

# اعلامیه امنیتی

این اسکریپت برای انجام آزمون‌های عملکرد، به باینری‌های خارجی وابستگی دارد. آزمون‌های شبکه با استفاده از iperf3 از باینری‌هایی استفاده می‌کند که کامپایل شده‌اند تا قابلیت باینری قابل حمل را داشته باشند. دلایل انجام این عمل شامل اطمینان از خروجی استاندارد (قابل تجزیه)، پشتیبانی از معماری‌های 32 بیتی و 64 بیتی، عبور از نیاز به کامپایل و/یا نصب پیش‌نیازها و دلایل دیگر است. برای استفاده از این اسکریپت به عنوان هر اسکریپت عمومی موجود در اینترنت، باید خطرات آن را در نظر بگیرید.
