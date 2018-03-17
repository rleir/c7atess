## Purpose:

*Run Optical Character Recognition on millions of images, using multiple machines and saving the results in a DB for analysis and other uses.*

We had 25 million images, averaging 5Mbytes each, some of which contained text of varying legibility. We wanted to be able to search the images using the Solr search engine, so we needed the text in UTF-8. OCR using the excellent Tesseract took a few minutes per image, and we did not have years for the job. 

If you have a small number of images, you may still be interested in  this project because the image preprocessing makes for  better OCR results from Tesseract.

You may be interested in  this project just to see how  CPU intensive tasks other than OCR can be run in parallel on multiple machines.

## Interface

A very basic web UI can be used to queue client jobs. A job is specified by the directory path, and all images in the tree are OCR'd. Currently, there is an email field for notification of results.   The UI shows the job qeue. Maybe in the future we will be able to re-order or cancel jobs. 

There is also a CLI for accepting a job.

## Engine

The scheduler accepts a job from the queue, traverses the directory tree, and sends per-image tasks to the workers so as to keep them optimally busy. Image format is JPG, JP2, and Tiff.  Each worker pre-processes an image for adaptive thresholding,  runs Tesseract, filters junk from the output, then saves the results to the OCR DB. The results include a .hocr file, raw text, and some statistics.

 The preprocessing is done in Graphicsmagick. It converts color to a greyscale.  It makes a copy of the image, applies blurring, then divides the two images pixel by pixel, giving a photocopy-like effect. If the source image had uneven lighting then that is lost.  If the print density varied, then that is mostly lost.  After this preprocessing,  Tesseract can choose any threshold in a wide range; it is not critical.

 The filtering removes junk 'word's that are all punctuation, or blank.

 When all images have been OCR'd, the job status is sent by email.

##DB

    mysql> describe ocr ;

|Field             | Type         | Null | Key | Default | Extra          |
-------------------|--------------|------|-----|---------|---------------
| idocr             | int(11)      | NO   | PRI | NULL    | auto_increment |
| imageFile         | varchar(200) | NO   | MUL | NULL    |                |
| ocrEngine         | varchar(45)  | NO   |     | NULL    |                |
| langParam         | varchar(8)   | NO   |     | NULL    |                |
| brightness        | int(11)      | NO   |     | NULL    |                |
| contrast          | int(11)      | NO   |     | NULL    |                |
| avgWordConfidence | int(11)      | YES  |     | NULL    |                |
| numWords          | int(11)      | YES  |     | NULL    |                |
| startOcr          | datetime     | YES  |     | NULL    |                |
| timeOcr           | int(11)      | YES  |     | NULL    |                |
| remarks           | varchar(45)  | YES  |     | NULL    |                |
| imageFileSize     | int(11)      | YES  |     | NULL    |                |
| outputText        | text         | YES  |     | NULL    |                |
| outputHocr        | blob         | YES  |     | NULL    |                |

###imageFile
   Contains file paths in the form of path/to/image/dir/0223.jpg

###ocrEngine
   Currently, this field is always 'tess3.03-IMdivide'.

###langParam
   Tesseract supposedly will work better if it is told by parameter which language it should expect, so it can make use of dictionaries. However, the results for  us are the same whether it is given 'eng' or 'fra'. Ideally we would like Tesseract  to tell us which language(s) it found, but we would do better to post-process the results, and count hits against French and English dictionaries.  Currently, this field is always 'eng'.

###brightness, contrast
   These fields are currently meaningless.

###avgWordConfidence
   This field records the average X_xconf value from the .hocr file.

###numWords
   This field records the number of words from the .hocr file

###startOcr, time Ocr
   The start time and elapsed time.

###remarks
   This field is unused.

###imageFileSize
   The size in bytes of the input image.

###outputText
   The resulting text from Tesseract, in UTF8

###outputHocr
   The resulting hOCR from Tesseract, compressed by gzip.

=====================================================

##Contributing: 
Pull requests are welcome.
   
##Discussion:
*   https://groups.google.com/forum/#!forum/tesseract-ocr
* open an issue here

##License: 
   Perl Artistic http://dev.perl.org/licenses/artistic.html

##To Do
*  -add your plans to this To Do list, or elaborate on it
*  -the Scheduler should be launched using a service, in the scope of a ocr-data user account.  Or there could be a control on the Dashboard to launch and stop it.
*  -Installation of the master needs to be automated, beyond what is done by installWorker.sh:  There needs to be a directory /var/run/ocr which is writeable by the user running this cat app.
*  -The documetation for database installation needs to be improved in the Install file.
*  -pluggable OCR engine and image preprocessing
*  -publish to CPAN
*  -bundle the CPAN modules for automated installation using Capistrano
*  -One idea is to run a spelling checker across everything. It will correct some stuff, but it will also make mistakes like changing a name to a word. So we can keep both   the original and the corrected word in the full text, and searches will work better.   See languagetool.org
*  -Also, when a word ends in a hyphen, we can join the following word and add that.  Especially when we have solved the column problems.
*  -We talked of multi-column, like newspapers. OCR should follow the column. In the pathological case, OCR spans across the page, getting the column text interleaved.    We could solve this by using Ocropus to find bounding boxes, then Tesseract to do the actual work.
*  -We talked of improvements in Adaptive thresholding. There is OpenCV, and the ImageMagick -lat feature
* -In some Arabic community there is ongoing work to modify Tesseract to recognize connected characters because Arabic is generally connected. Their algorithm is called Cube or similar,    and runs much slower, with uncertain results. I mention this because we could possibly do something with our cursive images (though only the cleanest copperplate grade).

##Contributors

* Rick Leir formerly richard.leir@canadiana.ca now rleir@leirtech.com
* Russell
* Tim


