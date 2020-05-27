# OLEKit

Swift support for Microsoft OLE2 format, also known as Structured Storage, [Compound File Binary Format](https://en.wikipedia.org/wiki/Compound_File_Binary_Format) or Compound Document File Format.

Some of the file formats that utilize it:

* Encrypted Office Open XML documents (Microsoft Office 2003+, Word `.docx`, Excel `.xlsx`, PowerPoint `.pptx`)
* Microsoft Office 97-2003 documents ([BIFF5 and later](https://www.gaia-gis.it/gaia-sins/freexl-1.0.5-doxy-doc/html/Format.html) in Word `.doc`, Excel `.xls`, PowerPoint `.ppt`, Visio `.vsd`, Project `.mpp`) 
* vbaProject.bin in MS Office 2007+ files
* Image Composer and FlashPix files
* Outlook messages
* StickyNotes
* Zeiss AxioVision ZVI files
* Olympus FluoView OIB files
* McAfee antivirus quarantine files

...and more. If you know of a file format that is based on CFBF, please submit [a pull request](https://github.com/MaxDesiatov/OLEKit/edit/master/README.md) so that it's added to the list.
