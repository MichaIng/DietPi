---
name: Bug report
about: Create a report to help us improve

---

### Creating a bug report/issue

#### Required Information
- DietPi version | `cat /DietPi/dietpi/.version`
- Distro version | `echo $G_DISTRO_NAME` or `cat /etc/debian_version`
- Kernel version | `uname -a`
- SBC device | `echo $G_HW_MODEL_DESCRIPTION` or (EG: RPi3)
- Power supply used | (EG: 5V 1A RAVpower)
- SDcard used | (EG: SanDisk ultra)

#### Additional Information (if applicable)
- Software title | (EG: Nextcloud)
- Was the software title installed freshly or updated/migrated?
- Can this issue be replicated on a fresh installation of DietPi?
<!-- If you sent a "dietpi-bugreport", please paste the ID here -->
- Bug report ID | `sed -n 5p /DietPi/dietpi/.hw_model`

#### Steps to reproduce
<!-- Explain how to reproduce the issue -->
1. ...
2. ...

#### Expected behaviour
<!-- What SHOULD be happening? -->
- ...

#### Actual behaviour
<!-- What IS happening? -->
- ...

#### Extra details
<!-- Please post any extra details that might help solve the issue -->
- ...
