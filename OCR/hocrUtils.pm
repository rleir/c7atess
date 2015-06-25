#
# Given a hOCR document, 
#   get just the text words,
#   count the words
#   get the word confidence values
package OCR::hocrUtils;

use common::sense;

use XML::LibXML;
use XML::LibXML::PrettyPrint;

use HTML::TagParser;
use HTML::FormatText;
use HTML::TreeBuilder;
use IO::HTML qw(html_file);
use List::MoreUtils qw(uniq);

use Encode qw(decode encode);

use Image::Info qw(image_info dim);

use vars qw(@ISA @EXPORT @EXPORT_OK $VERSION); #  %EXPORT_TAGS
use Exporter;
$VERSION = 0.98;
@ISA = qw(Exporter);
@EXPORT = qw( hocr2words hocr2txtmap hocr2html doFilterHocr);

# get just the text out of the .hocr file
sub getUnformattedText {
    my ($outHcr) =  @_;

    # open the HOCR file and sniff the encoding, and apply it. 
    my $hocrfilehandle = html_file($outHcr); # , \%options);

    # This "shortcut" constructor implicitly calls $new->parse_file(...)
    my $tree = HTML::TreeBuilder->new_from_file(  $hocrfilehandle);

    # get just the text from the hocr
    my $formatter = HTML::FormatText->new( leftmargin => 0, rightmargin => 500);
    my $unformattedtext = $formatter->format($tree);

    my $utf8flag = utf8::is_utf8($unformattedtext);
    my $diagnostic;
    if( ! $utf8flag) {
        $diagnostic = "WARN unformattedtext == utf8 == false $outHcr \n";
    };
    return ($unformattedtext, $diagnostic) ;
}

# count the words
sub countWords {
    my ( $unformattedtext) = @_;
    # get the text into an array
    my @dup_list = split(/ /, $unformattedtext);
    # sort uniq
    my @uniq_list = uniq(@dup_list);
    # count words
    my $nwords = scalar @uniq_list;
    # put all in a string
    #my $wordList = join(' ', @uniq_list);  # zzz not used
    return $nwords;
}

# for each word get the confidence
# compute the average word confidence (weighted by word frequency)
# the return is the average and the number of words
sub saveStats {
    my ( $outHcr,  $outStats) = @_;

    # get just the x_wconf values from the hocr file:
    my $confsum = 0;
    my $confcount = 0;

    my $html = HTML::TagParser->new( $outHcr );
    my @list = $html->getElementsByTagName( "span" );
    foreach my $elem ( @list ) {
	my $innertext = $elem->innerText;

	my $titlevalue = $elem->getAttribute( "title" );
	if ( $titlevalue =~ / x_wconf ([0-9]*)/ ) {
	    $confsum += $1;
	    $confcount ++;
	}
    }
    # avoid divide by zero
    if( $confcount == 0) { $confcount ++; }
    my $avg = $confsum / $confcount;

    return ($avg, $confcount) ;
}

#  main ========================
# given the .hocr content, get just the text with no formatting
sub hocr2words {
    my ( $outHcr) =  @_;

    my $avgwconf = 0;
    my $nwords = 0;
    my $nwords2 = 0;

    # get just the text out of the .hocr file, and save it to the .txt file
    my ($unformattedtext, $diagnostic) = getUnformattedText($outHcr);

    if ( ! $diagnostic) { # should be throwing exceptions instead of this 

            if ( ! $unformattedtext) {
                $diagnostic = "WARN no unformatted text \n";
            } else {

                # count the words
                $nwords = countWords( $unformattedtext);
            }
            # save the word confidence values
            ($avgwconf, $nwords2) = saveStats( $outHcr);
    }

    return ($avgwconf, $nwords, $nwords2, $unformattedtext, $diagnostic);
}

# hocr2html ========================
# http://blog.humaneguitarist.org/2012/07/14/okra-pie-some-simple-ocrhocr-tests/
# given the .hocr content, produce an html with a word position layer.
# inhocr is a string containing the hocr
# imgFile is a web relative path to the image
sub hocr2html {
    my ( $unfilthocr, $fontSize ) =  @_;

    if( ! $fontSize) {
        $fontSize = 40;
    }

    # filter junk. soon this step will not be necessary, 
    # when we are writing filtered hocrs to the DB,
    # and when the existing DB records have been filtered.
    my $inhocr = doFilterHocr ( $unfilthocr);

    # get input
    my $html = HTML::TagParser->new( $inhocr );

    my $imgFile;
    my @titlelist = $html->getElementsByTagName( "div" );
    my $elem = $titlelist[0];
    my $titlevalue = $elem->getAttribute( "title" );

    # ignore all but the filename
    my ($fullimgFile) = $titlevalue =~ /image \"(.*)\"; bbox ([0-9]*) ([0-9]*) ([0-9]*) ([0-9]*); ppageno ([0-9]*)/;
    # warn "fullimgFile $fullimgFile";

    my $p1 = $fullimgFile;
    $p1 =~ s/^\/tdr/\/collections.new\/pool1\/aip/ ;
    if( -e $p1) {
        #warn "exists p1 $p1";
        $imgFile = $p1;
    } else {

        my $p2 = $fullimgFile;
        $p2 =~ s/^\/tdr/\/collections.new\/pool2\/aip/ ;
        if( -e $p2) {
            #warn "exists p2 $p2";
            $imgFile = $p2;
        }
    }

    my @list = $html->getElementsByTagName( "span" );
  
    # output to ..
    my $htmlOut = <<ENDHTML;
<!DOCTYPE html>
<html>
  <head>
    <title>Image View</title>
    <meta charset="UTF-8" />
    <script type="text/javascript">
      function hideImage(){
        var im = document.getElementById("image");
        var ocr = document.getElementById("ocr");
        im.style.display = "none";
        ocr.style.color = "black";
      }
      function showImage(){
        var im = document.getElementById("image");
        var ocr = document.getElementById("ocr");
        im.style.display = "block";
        ocr.style.color = "transparent";
      }
    </script>
  </head>
  <body>
    <div id= "image" style="position:absolute;z-index:-1">
ENDHTML

    # tif file? need to convert to jpg
    if( $imgFile =~ /.*tif$/ ) {

        my $info = image_info( $imgFile);
        if (my $error = $info->{error}) {
            die "Can't parse image info: $imgFile $error\n";
        }
        #print $info->{BitPerSample};

        my($width, $height) = dim($info);

        $htmlOut .= "<embed width=$width height=$height src='$imgFile' type='image/tiff' negative=yes />";
    } else {
        $htmlOut .= "<img src='$imgFile' />";
    }
    $htmlOut .= " </div> \n";
    $htmlOut .= "<div id='ocr' style='color:transparent;opacity:0.5;background-color:transparent;'> \n";

    foreach my $elem ( @list ) {
        my $classvalue = $elem->getAttribute( "class" );

        # ignore all but word spans
        if ( $classvalue ne "ocrx_word") { next;};

        my $innertext = $elem->innerText; # <strong>Open-Air-</strong>

        # ignore blank words ( though filtering will leave none)
        if ( $innertext eq "")   { next;};
        if ( $innertext =~ / +/) { next;};

        # ignore words which are just punctuation ( though filtering will leave none)
        if ( $innertext =~ /[[:punct:]]/) { next;};

        my $titlevalue = $elem->getAttribute( "title" );

        # looking for: bbox x0 y0 x1 y1;
        if ( $titlevalue =~ /bbox ([0-9]*) ([0-9]*) ([0-9]*) ([0-9]*); x_wconf ([0-9]*)/ ) {
            my $x0 = $1;  # bbox x0 y0 x1 y1;
            my $y0 = $2;
            my $x1 = $3;
            my $y1 = $4;
            # $wconf = $5 not used here
            my $width  = $x1 - $x0;
            my $height = $y1 - $y0;
            $htmlOut .= " <span style='left:${x0}px;top:${y0}px;width:${width}px;height:${height}px;";
            $htmlOut .= " font-size:${fontSize}px;position:absolute;'>$innertext</span>\n";
        }
    }
    $htmlOut .= " </div> </body> </html>\n";
    return $htmlOut;
}

# hocr2txtmap ========================
# given the .hocr content, produce txtmap info.
sub hocr2txtmap {
    my ( $inhocr ) =  @_;

    my $html = HTML::TagParser->new( $inhocr );
    my @list = $html->getElementsByTagName( "span" );
  
#    my $hocr  = XML::LibXML->load_xml(location => $hocrfile);
#    my $xpc = XML::LibXML::XPathContext->new($hocr);
#    $xpc->registerNs('hocr', 'http://www.w3.org/1999/xhtml');

    my $txtmap = XML::LibXML::Document->new('1.0', 'UTF-8');
    my $root = $txtmap->createElementNS('http://canadiana.ca/schema/2012/xsd/txtmap', 'txtmap');
    $txtmap->setDocumentElement($root);

    my $txtmap_page = $txtmap->createElement('page');
    $root->appendChild($txtmap_page);

    foreach my $elem ( @list ) {
        my $classvalue = $elem->getAttribute( "class" );

        # ignore all but word spans
        if ( $classvalue ne "ocrx_word") { next;};

        my $innertext = $elem->innerText; # <strong>Open-Air-</strong>

        # ignore blank words
        if ( $innertext eq "")   { next;};
        if ( $innertext =~ / +/) { next;};

        # ignore words which are just punctuation
        if ( $innertext =~ /[[:punct:]]/) { next;};

        my $x0;
        my $y0;
        my $x1;
        my $y1;
        my $titlevalue = $elem->getAttribute( "title" );

        # looking for: bbox x0 y0 x1 y1;
        if ( $titlevalue =~ /bbox ([0-9]*) ([0-9]*) ([0-9]*) ([0-9]*); x_wconf ([0-9]*)/ ) {
            $x0 = $1;  # bbox x0 y0 x1 y1;
            $y0 = $2;
            $x1 = $3;
            $y1 = $4;
            # $wconf = $5 not used here
            
            # output format
            # <w T="255" L="276" W="145" H="34">Hello,</w>
            my $txtmap_word = $txtmap->createElement('w');
            $txtmap_word->setAttribute('T', $y0 );     # y increases from top to bottom
            $txtmap_word->setAttribute('L', $x0 );
            $txtmap_word->setAttribute('W', $x1 - $x0);
            $txtmap_word->setAttribute('H', $y1 - $y0);
            $txtmap_word->appendChild($txtmap->createTextNode( $innertext));
            $txtmap_page->appendChild($txtmap_word);
        }
    }
    my $pp = XML::LibXML::PrettyPrint->new(indent_string => "  ");
    $pp->pretty_print($txtmap); # modified in-place
    return $txtmap;
}

# doFilterHocr ==================================
# filter junk out of a .hocr
#   -this sub can be called one or many times with the same result
#   -the code is not efficient, but it needs to be correct.
#   -when you have time to do the testing, you can optimise this
sub doFilterHocr {
    my ($rawhocr) =  @_;

    my $inhocr = transLigatures( $rawhocr); #  \x{FB00}  becomes ff

    # read file to libXML
    my $doc = XML::LibXML->load_html(
        string => $inhocr
        # parser options ...
        );

    onePassFilter ( $doc); # remove any junk words
    onePassFilter ( $doc); # remove any empty lines
    onePassFilter ( $doc); # remove any empty par's
    onePassFilter ( $doc); # remove any empty carea's

    my $trhocr = $doc->toString;
    my $inhocr = correctPath ( $trhocr); # title image path is incorrect as written by tess

    return( $inhocr);
}

# Replace ligatures with separate characters
#  \x{FB00}  becomes ff
sub transLigatures {
    my ($rawhocr) =  @_;

    my $hocr = decode( 'UTF8', $rawhocr );

    #if( $hocr =~ /\x{FB01}/ ) {
    #    warn "contains fi";    }

    $hocr =~ s/\x{0132}/IJ/g;
    $hocr =~ s/\x{0133}/ij/g;

    $hocr =~ s/\x{0152}/OE/g;
    $hocr =~ s/\x{0153}/oe/g;

    $hocr =~ s/\x{FB00}/ff/g;
    $hocr =~ s/\x{FB01}/fi/g;
    $hocr =~ s/\x{FB02}/fl/g;
    $hocr =~ s/\x{FB03}/ffi/g;
    $hocr =~ s/\x{FB04}/ffl/g;
    $hocr =~ s/\x{FB05}/\x{017F}t/g; # long-s t
    $hocr =~ s/\x{FB06}/st/g;

    $hocr =~ s/\x{A7F9}/oe/g;

    my $octets = encode('UTF8', $hocr);
    return $octets;
}

# the title image path is incorrect as written by tess
# note that we assume that libXML has had a pass thru the doc already, so '"' became &quot;
#    and ''' became '"' in ...
sub correctPath  {
    my ($hocr) =  @_;

    # if( $hocr =~ /(div class="ocr_page" id="page_1" title="image \&quot;\/.{22})/ ) { warn $1; }

    # if the correct path is not found
    my $found = $hocr =~ /div class="ocr_page" id="page_1" title="image \&quot;\/tdr\// ;

    if( ! $found ) {
        # my ($deb) = $hocr =~ /(div class="ocr_page" id="page_1" title="image .{32})/ ;
        # warn "correcting path $deb" ;

        # correct this error (from when a worker did the image)
        $hocr =~ s/\/home\/richard\/collections.new\/pool[12345]\/aip/\/tdr/ ;

        # or correct this error (from when the manager did the image)
        $hocr =~ s/\/var\/lib\/catalyst\/OCR\/collections.new\/pool[12345]\/aip/\/tdr/ ;
        
        # or correct this error (from the first month, long ago)
        $hocr =~ s/\/home\/rleir\/ocr\/pdfocr\/collections\/tdr/\/tdr/ ;
    }
    return $hocr;
}

# scan all nodes in doc, removing junk
sub onePassFilter {
    my ($doc) =  @_;

    my $cur = $doc->firstChild;
    while ($cur) {
        my $next;

        my $pathuri = $cur->nodePath();
        # print "5   $pathuri \n";

        my $delNode = 0;
        # print Dumper( ref $cur);
        if ( $cur->nodeName eq "xml")        { $delNode=1;};

        if (ref $cur eq "XML::LibXML::Element") {

            for my $att ($cur->attributes) {
                my $delAttr=0;
                my $attrOwner;

                my $aname = $att->nodeName;
                #print "att->nodeName " . $aname . " \n";
                #print Dumper( $att->nodeValue );

                # libxml will be adding this attr
                if( $aname eq 'xmlns')    { $delAttr=1; }; 

                if( $aname eq 'xml:lang') { 
                    $delAttr=1; 
                    #print "deleting attr, name " . $aname . " val " .  $att->nodeValue . "\n";
                }; 

                if( $delAttr == 1) {
                    $attrOwner = $att->getOwnerElement();
                }

                if( $aname eq 'class'
                    && $att->nodeValue eq 'ocr_carea') {
                    my @childnodes = $cur->childNodes();
                    my $numChild = @childnodes;
                    my @NBchildnodes = $cur->nonBlankChildNodes();
                    my $NBnumChild = @NBchildnodes;

                    #print "attr class is ocr_par, delnode is $delNode  numChild is $numChild $NBnumChild \n";
                    if ( $NBnumChild <= 0)   { $delNode=1; };           # print Dumper( "deleting 1"  );};
                }

                if( $aname eq 'class'
                    && $att->nodeValue eq 'ocr_par') {
                    my @childnodes = $cur->childNodes();
                    my $numChild = @childnodes;
                    my @NBchildnodes = $cur->nonBlankChildNodes();
                    my $NBnumChild = @NBchildnodes;

                    #print "attr class is ocr_par, delnode is $delNode  numChild is $numChild $NBnumChild \n";
                    if ( $NBnumChild <= 0)   { $delNode=1; };           # print Dumper( "deleting 1"  );};
                }

                if( $aname eq 'class'
                    && $att->nodeValue eq 'ocr_line') {
                    my @childnodes = $cur->childNodes();
                    my $numChild = @childnodes;
                    my @NBchildnodes = $cur->nonBlankChildNodes();
                    my $NBnumChild = @NBchildnodes;

                    # print "attr class is ocr_line, delnode is $delNode  numChild is $numChild $NBnumChild \n";
                    if ( $NBnumChild <= 0)   { $delNode=1; };           # print Dumper( "deleting 1"  );};
                }

                if( $aname eq 'class'
                    && $att->nodeValue eq 'ocrx_word') {
                    
                    my $innertext = $cur->textContent ;
                    # ignore blank words
                    if ( $innertext eq "")   { $delNode=1; };           # print Dumper( "deleting 1"  );};
                    if ( $innertext =~ /[\h\v]+/) { $delNode=1; };      # print Dumper( "deleting 4"  );};
                
                    # ignore words which are just punctuation
                    if ( $innertext =~ /^[[:punct:]]$/) { $delNode=1;}; # print Dumper( "deleting 5"  );};

                    # print "nodeName is \n";
                    # print Dumper( $cur->nodeName);
                    # print "attr class is ocrx_word, txt is " .  $innertext . " delnode is " . $delNode . " \n";
                }
                if( $delAttr == 1) {
                    # $att->nodeName;
                    $att->unbindNode();
                }
            }
        }
        # find the next node
        if ( $delNode != 1) {
            # does a child exist?
            my $child = $cur->firstChild;
            ## now descend if any kids
            if ( $child) {
                $next = $child;
                # print "descending to " . $next->nodeName . " val " .  $next->nodeValue . "\n";
            }
        }  

        if ( ! $next) {
            # next sibling
            $next = $cur->nextSibling; # might be null
        }

        if ( ! $next) {
            my $nodePtr = $cur;
            my $sib;
            while ( ! $sib) {
                ## no sibling... must try parent node's sibling
                my $parent = $nodePtr->parentNode;
                
                # finished if no parent
                if ( ! $parent) {
                    last;  # break out of the loop
                }
                $sib = $parent->nextSibling;
                if ( ! $sib) {
                    $nodePtr = $parent;
                }
            }
            $next = $sib;         # might be null
        }
        # delete the current node if needed
        if ( $delNode == 1) {
            # print "deleting node, name " . $cur->nodeName . " content " . $cur->textContent . "\n";
            # print "parent   node, name " . $cur->parentNode->nodeName .  "\n";
            $cur->removeChildNodes();
            $cur->unbindNode();
            #$cur->parentNode->removeChild($cur);
        } 
        ## $next might be undef at this point, and we'll be done
        $cur = $next;
    }
}

#====================
