Images
======

Definitions of images available in the HTTP repository. This is only for
the client playbooks: `add-baremetal.yml` and `add-vbox.tml`. Files on this
folder will be used whether, in the definition of a host in `servers` folder, 
the parameter `baremetal_os` references one (by name, without the extension).

Each file defines the resources needed to deploy an image, main parameters are:

 * `baremetal_driver`. Due to the fact an image can be a full disk image 
(vs just a partition), some drivers do not know how to handle all type of images.
 * `baremetal_deploy_kernel`, `baremetal_deploy_ramdisk`, because of the 
the previous point, these are specific parameters needed by the driver.
 * `baremetal_image_type`: *Debian* or *RedHat* to create the networking files 
in the configdrive volume (see `configdrive` role).
 * `baremetal_image`: link to the HTTP repository where the image is
 * `baremetal_image_checksum`: MD5 checksum of the image, if not defined
the tasks in `tasks/baremetal_md5` will look for a file, on the same repository
of the image, using the `.meta` extension instead of the original extension of
the image. If such file is not found, the image will be downloaded to calculate
the MD5 checksum locally (and it takes a lot of time!).

After define an host here, the client playbooks will load the definition of
a server, which will point to a definition of an image here.
