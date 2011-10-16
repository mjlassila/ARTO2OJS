<?xml version="1.0" encoding="UTF-8"?>
<!--

  ARTO2OJS

  This XSL template is free software: you can redistribute
  it and/or modify it under the terms of the GNU Lesser
  General Public License (GNU LGPL) as published by the Free Software
  Foundation, either version 3 of the License, or (at your option)
  any later version. The code is distributed WITHOUT ANY WARRANTY;
  without even the implied warranty of MERCHANTABILITY or FITNESS
  FOR A PARTICULAR PURPOSE. See the GNU GPL for more details.

  As additional permission under GNU GPL version 3 section 7, you
  may distribute non-source (e.g., minimized or compacted) forms of
  that code without the copy of the GNU GPL normally required by
  section 4, provided you include this license notice and a URL
  through which recipients can access the Corresponding Source.

  Copyright (C) 2011 Matti Lassila (matti.lassila@gmail.com)

  ARTO2OJS -muunnostiedosto

  Tyylitiedosto muuntaa ARTO-tietokannan viitteidenhallintatyökalun
  tuottaman MARCXML-tiedoston Open Journals System julkaisualustan
  Articles & Issues -muotoon. Luettelointikäytäntöjen vaihtelun vuoks
  muunnos ei ole virheetön, joten tuloksen läpikäynti esimerkiksi
  BaseX -ohjelman (http://www.basex.org) tai editorin avulla on suositeltavaa.

  ARTO2OJS - briefly in english
  ARTO2OJS is stylesheet for transforming MARC21 data from Finnish national
  database of journals and periodicals (ARTO) to Open Journals System
  "Articles & Issues" import format. With luck (and some modifications),
  it might work with MARC from other sources too.

-->
<!--==============================================================-->

<!-- Top level styles. Transformation is done in two steps.
      First step creates basic metadata structures, second groups
      and arrages articles in correct order -->

<xsl:stylesheet xmlns:xsl="http://www.w3.org/1999/XSL/Transform" version="2.0"
  exclude-result-prefixes="xsl lang functx"
  extension-element-prefixes="debug"
  xmlns:functx="http://www.functx.com"
  xmlns:xs="http://www.w3.org/2001/XMLSchema"
  xmlns:lang="lang.uri"
  xmlns:debug="debug.uri">

  <xsl:output encoding="utf-8" indent="yes" method="xml" cdata-section-elements="email"/>
  <xsl:output method="xml" name="xml" indent="yes" doctype-system="native.dtd"/>
  <xsl:preserve-space elements="email"/>

  <!-- Command line parameter for selecting locale source, eg.
       should we use locale from article metadata or default to OJS default -->
  <xsl:param name="use_metadata_locale" select="'false'" />
  <xsl:variable name="use_locale" select="$use_metadata_locale = 'true'" />

  <!-- Language codes for locale settings. -->

  <lang:languages>
    <lang:language code="fin" locale="fi_FI"/>
    <lang:language code="swe" locale="sv_SV"/>
    <lang:language code="eng" locale="en_US"/>
    <lang:language code="ger" locale="de_DE"/>
  </lang:languages>


  <!-- Variable which includes lang:languages -->
  <xsl:variable name="lang-top" select="document('')/*/lang:languages"/>



  <xsl:template match="/">


    <xsl:variable name="temporary-collection">
      <xsl:call-template name="gen-temporary-collection">
        <xsl:with-param name="collection" select="collection"/>
      </xsl:call-template>
    </xsl:variable>

    <xsl:variable name="result-collection">
      <xsl:call-template name="issues">
        <xsl:with-param name="all-issues" select="$temporary-collection/issues"/>
      </xsl:call-template>
    </xsl:variable>

    <xsl:variable name="input-file">
      <xsl:value-of select="functx:substring-after-last(base-uri(), '/')"/>
    </xsl:variable>

    <xsl:variable name="result-file">
      <xsl:text>ojs-xml_</xsl:text>
      <xsl:value-of select="$input-file"/>
    </xsl:variable>

    <xsl:result-document href="{$result-file}" format="xml">
      <xsl:copy-of select="$result-collection"/>
    </xsl:result-document>

  </xsl:template>

<!-- Template for checking the result of first transformation
<xsl:template match="/">

          <xsl:call-template name="gen-temporary-collection">
              <xsl:with-param name="collection" select="collection"/>
          </xsl:call-template>
</xsl:template>
-->

  <xsl:template name="gen-temporary-collection">
    <xsl:param name="collection"/>
      <issues>
        <xsl:apply-templates select="$collection/record"/>
      </issues>
  </xsl:template>

<!--===================================================================================================================-->

  <!--Yksittäinen tietue. Väliaikainen rakenne.-->
  <xsl:template match="record">
     <!-- Kieli -->
     <xsl:variable name="language">
       <xsl:call-template name="trimp">
         <xsl:with-param name="str" select="datafield[@tag='041'][1]/subfield[@code='a'][1]"/>
       </xsl:call-template>
    </xsl:variable>

    <xsl:variable name="locale-temp">
      <xsl:value-of select="$lang-top/lang:language[@code=$language]/@locale"/>
    </xsl:variable>


    <xsl:variable name="locale">
      <xsl:choose>
        <xsl:when test="string-length($locale-temp)!=0 and $use_locale">
          <xsl:value-of select="$locale-temp"/>
        </xsl:when>
        <!-- Käytetään oletuksena OJS:n localea -->
        <xsl:otherwise>
          <xsl:text/>
        </xsl:otherwise>
      </xsl:choose>
    </xsl:variable>



      <issue published="true" current="false" identification="title">
        <article>
          <!-- Title -->
          <xsl:apply-templates select="datafield[@tag=245]">
            <xsl:with-param name="locale" select="$locale"/>
          </xsl:apply-templates>

          <indexing>
          <!-- Subject Added Entry-Personal Name-->
          <xsl:apply-templates select="datafield[@tag='600']"/>
          <!-- Geographical subject entiers -->
          <xsl:apply-templates select="datafield[@tag='650']"/>
          <xsl:apply-templates select="datafield[@tag='651']"/>
          <!-- Termi, jonka sanastoa ei tiedetä -->
          <xsl:apply-templates select="datafield[@tag='653']"/>
          <!-- Terms indicating the genre, form, and/or physical characteristics of the materials being described-->
          <xsl:apply-templates select="datafield[@tag='655']/subfield[@code='a']"/>
          <!--Täytyy olettaa, että käytössä on vain yksi sanasto. Tuontiformaatti ei tarjoa keinoa yhdistää sanastoa asiasanoihin -->
          <xsl:apply-templates select="datafield[@tag=650][1]/subfield[@code='2']" />
          </indexing>


          <!-- Päävastuullinen kirjoittaja -->
          <xsl:apply-templates select="datafield[@tag=100]" />
          <!-- Muut kirjoittajat -->
          <xsl:apply-templates select="datafield[@tag=700]"/>

          <!-- Sivunumerot. Kenttä 773 toistetaan,
          OJS-yhteensopivuuden vuoksi on valittava vain yksi kenttä.
          Valitaan ensimmäinen kenttä -->
          <xsl:apply-templates select="datafield[@tag='773'][1]/subfield[@code='g']" />

          <!-- Julkaisupäivä verkossa -->
          <xsl:apply-templates select="controlfield[@tag=005]" />

          <!-- URI tiedostoon -->
          <xsl:apply-templates select="datafield[@tag=856 and @ind2=0]" />

          <!-- Locale. This is only for transformation. OJS doesn't see this field. -->
          <locale><xsl:value-of select="$locale"/></locale>

        </article>

        <issuedata>
          <!-- Julkaisutiedot kentässä 773 -->
          <xsl:apply-templates select="datafield[@tag=773][1]"/>
        </issuedata>

      </issue>
  </xsl:template>


  <!--Kenttätemplatet-->

  <!--Artikkelin pääotsikko-->
  <xsl:template match="datafield[@tag=245]">
    <xsl:param name="locale"/>
    <xsl:variable name="title">
      <xsl:call-template name="trimp">
        <xsl:with-param name="str" select="subfield[@code='a']"/>
      </xsl:call-template>
    </xsl:variable>

    <xsl:variable name="subtitle">
      <xsl:call-template name="trimp">
        <xsl:with-param name="str" select="subfield[@code='b']"/>
      </xsl:call-template>
    </xsl:variable>

    <xsl:variable name="fulltitle">
       <xsl:choose>
         <xsl:when test="subfield[@code='b']">
           <xsl:value-of select="concat($title, ': ', $subtitle)"/>
         </xsl:when>
         <xsl:otherwise>
           <xsl:value-of select="subfield[@code='a']"/>
         </xsl:otherwise>
       </xsl:choose>
    </xsl:variable>

    <title locale="{$locale}">
      <xsl:call-template name="trimp">
        <xsl:with-param name="str" select="$fulltitle"/>
      </xsl:call-template>
    </title>

  </xsl:template>

  <!--Artikkelin päävastuullinen kirjoittaja-->
  <xsl:template match="datafield[@tag=100 or @tag=700]">
    <xsl:variable name="primary-author">
      <xsl:choose>
        <xsl:when test="contains(@tag,'100')">
          <xsl:value-of select="'true'"/>
        </xsl:when>
        <xsl:otherwise>
          <xsl:value-of select="'false'"/>
        </xsl:otherwise>
      </xsl:choose>
    </xsl:variable>

    <xsl:variable name="lastname" >
      <xsl:choose>
        <xsl:when test="contains(subfield[@code='a'], ',')">
          <xsl:value-of select="substring-before(./subfield[@code='a'],', ')"/>
        </xsl:when>
        <xsl:otherwise>
          <xsl:call-template name="trimp">
            <xsl:with-param name="str" select="subfield[@code='a']"/>
          </xsl:call-template>
        </xsl:otherwise>
      </xsl:choose>
    </xsl:variable>

    <xsl:variable name="firstname">
      <xsl:choose>
        <xsl:when test="contains(subfield[@code='a'], ',')">
          <xsl:value-of select="substring-after(./subfield[@code='a'],', ')"/>
        </xsl:when>
        <xsl:otherwise>
          <xsl:value-of select="'Nimimerkki'"/>
        </xsl:otherwise>
      </xsl:choose>
    </xsl:variable>

    <author primary_contact="{$primary-author}">
      <firstname>
        <xsl:call-template name="trimp">
          <xsl:with-param name="str" select="$firstname"/>
        </xsl:call-template>
      </firstname>
      <lastname>
       <xsl:call-template name="trimp">
         <xsl:with-param name="str" select="$lastname"/>
       </xsl:call-template>
      </lastname>

      <email><xsl:text><![CDATA[  ]]></xsl:text></email>

    </author>
  </xsl:template>

  <!-- Viite tiedostoon -->
  <xsl:template match="datafield[@tag='856' and @ind2='0']">
    <xsl:variable name="file" select="subfield[@code='u']" />
    <xsl:variable name="mimetype">
      <xsl:choose>
        <xsl:when test="ends-with($file, 'pdf')">application/pdf</xsl:when>
        <xsl:when test="ends-with($file, 'html')">text/html</xsl:when>
        <xsl:otherwise>application/octet-stream</xsl:otherwise>
      </xsl:choose>
    </xsl:variable>

    <galley>
      <label>Artikkeli</label>
      <file>
        <href src="{$file}" mime_type="{$mimetype}" />
      </file>
    </galley>
  </xsl:template>

  <!--Viimeisin tietueelle tehty transaktio. Käytetään tätä julkistamispäivänä. -->
  <xsl:template match="controlfield[@tag=005]">
    <xsl:variable name="year" select="substring(.,1,4)"/>
    <xsl:variable name="month" select="substring(.,5,2)"/>
    <xsl:variable name="day" select="substring(.,7,2)"/>

    <date_published><xsl:value-of select="$year"/>-<xsl:value-of select="$month"/>-<xsl:value-of select="$day"/></date_published>
  </xsl:template>

  <!--Numeron julkaisutiedot. -->
  <xsl:template match="datafield[@tag=773]">
    <xsl:variable name="number-and-order" select="normalize-space(substring-after(./subfield[@code='g'], ':'))"/>
    <xsl:variable name="numbering">
      <xsl:value-of select="replace(translate(subfield[@code='g'], ' ', ''),'V?v?ol\.?', '')"/>
    </xsl:variable>
    <xsl:variable name="pages" select="substring-after($numbering, 's.')"/>
    <xsl:choose>
      <xsl:when test="contains($numbering, '(')">
         <xsl:variable name="title">
           <xsl:value-of select="subfield[@code='t']"/>
           <xsl:if test="subfield[@code='b']">. - <xsl:value-of select="subfield[@code='b']"/></xsl:if>
         </xsl:variable>

         <journalname>
           <xsl:call-template name="trimp">
             <xsl:with-param name="str" select="$title"/>
           </xsl:call-template>
         </journalname>

         <xsl:choose>
           <xsl:when test="contains($number-and-order, 'artikkeli')">
             <order>
               <xsl:value-of select="
                  normalize-space(
                      substring-after(
                          substring-before($number-and-order, '. artikkeli'), ',')
                          )"/>
             </order>
           </xsl:when>
         </xsl:choose>
         <xsl:choose>
          <!--Publication: date of publication-->
            <xsl:when test="../datafield[@tag='260']/subfield[@code='c']">
              <year>
                <xsl:call-template name="trimp">
                  <xsl:with-param name="str" select="../datafield[@tag='260']/subfield[@code='c']"/>
                </xsl:call-template>
              </year>
            </xsl:when>
            <!--Publication: date of publication-->
            <xsl:when test="../controlfield[@tag='008']">
              <year>
                <xsl:value-of select="substring(../controlfield[@tag='008'], 8, 4)"/>
              </year>
            </xsl:when>
          </xsl:choose>
          <xsl:choose>
            <xsl:when test="contains($numbering, ':')">
              <volume><xsl:value-of select="substring-before($numbering, '(')"/></volume>
              <xsl:choose>
                <xsl:when test="contains($numbering, ',s.')">
                  <xsl:variable name="item">
                    <xsl:value-of select="substring-before(substring-after($numbering, '):'), ',s.')"/>
                  </xsl:variable>
                    <issue>
                      <xsl:call-template name="trimp">
                        <xsl:with-param name="str" select="$item"/>
                      </xsl:call-template>
                    </issue>
                  <xsl:variable name="page">
                    <xsl:choose>
                      <xsl:when test="contains($pages, '-')">
                        <xsl:call-template name="trim">
                          <xsl:with-param name="str" select="substring-before($pages, '-')"/>
                        </xsl:call-template>
                      </xsl:when>
                      <xsl:otherwise>
                        <xsl:value-of select="$pages"/>
                      </xsl:otherwise>
                    </xsl:choose>
                  </xsl:variable>

                  <order><xsl:value-of select="$page"/></order>

                </xsl:when>
                <xsl:otherwise>
                  <xsl:variable name="item"><xsl:value-of select="substring-before(substring-after($numbering, ':'), ',')"/></xsl:variable>
                    <issue>
                      <xsl:call-template name="trimp">
                        <xsl:with-param name="str" select="$item"/>
                      </xsl:call-template>
                    </issue>
                </xsl:otherwise>
              </xsl:choose>
           </xsl:when>
           <xsl:when test="contains($numbering, ';')">
              <volume><xsl:value-of select="substring-before($numbering, '(')"/></volume>
              <xsl:variable name="item"><xsl:value-of select="substring-before(substring-after($numbering, ';'), ',s.')"/></xsl:variable>
              <issue>
                <xsl:call-template name="trimp">
                  <xsl:with-param name="str" select="$item"/>
                </xsl:call-template>
              </issue>
              <xsl:variable name="item"><xsl:value-of select="substring-before(substring-after($numbering, '):'), ',s.')"/></xsl:variable>
              <issue>
                <xsl:call-template name="trimp">
                  <xsl:with-param name="str" select="$item"/>
                </xsl:call-template>
              </issue>
              <xsl:variable name="page">
                <xsl:choose>
                  <xsl:when test="contains($pages, '-')">
                    <xsl:call-template name="trim">
                      <xsl:with-param name="str" select="substring-before($pages, '-')"/>
                    </xsl:call-template>
                  </xsl:when>
                  <xsl:when test="contains($number-and-order,'.artikkeli')">
                    <xsl:value-of select="
                       normalize-space(
                           substring-after(
                               substring-before($number-and-order, '.artikkeli'), ',')
                               )"/>
                  </xsl:when>
                  <xsl:otherwise>
                    <xsl:value-of select="$pages"/>
                  </xsl:otherwise>
                </xsl:choose>
              </xsl:variable>
              <order>
                <xsl:value-of select="$page"/>
              </order>
           </xsl:when>
           <xsl:otherwise>
             <xsl:choose>
               <xsl:when test="substring($numbering, 1, 4) = 'Vol.' or substring($numbering, 1, 4) = 'vol.'">
                 <volume>
                   <xsl:call-template name="trim">
                     <xsl:with-param name="str" select="substring(substring-before($numbering, '('), 5)"/>
                   </xsl:call-template>
                 </volume>
               </xsl:when>
               <xsl:otherwise>
                 <xsl:call-template name="issuedata">
                   <xsl:with-param name="numbering" select="$numbering"/>
                 </xsl:call-template>
               </xsl:otherwise>
             </xsl:choose>
           </xsl:otherwise>
         </xsl:choose>
      </xsl:when>
      <xsl:when test="contains($numbering, ':')">
        <xsl:variable name="title">
          <xsl:value-of select="subfield[@code='t']"/>
            <xsl:if test="subfield[@code='b']">. - <xsl:value-of select="subfield[@code='b']"/></xsl:if>
        </xsl:variable>

        <journal>
          <xsl:call-template name="trimp">
            <xsl:with-param name="str" select="$title"/>
          </xsl:call-template>
        </journal>

        <xsl:choose>
          <xsl:when test="contains($number-and-order, 'artikkeli')">
            <order>
              <xsl:value-of select="
                  normalize-space(
                      substring-after(
                          substring-before($number-and-order, '. artikkeli'), ',')
                          )"/>
            </order>
          </xsl:when>
        </xsl:choose>
        <xsl:choose>
          <!--Publication: date of publication-->
          <xsl:when test="datafield[@tag='260']/subfield[@code='c']">
            <year>
              <xsl:call-template name="trimp">
                <xsl:with-param name="str" select="datafield[@tag='260']/subfield[@code='c']"/>
              </xsl:call-template>
            </year>
          </xsl:when>
          <!--Publication: date of publication-->
          <xsl:when test="controlfield[@tag='008']">
            <year><xsl:value-of select="substring(controlfield[@tag='008'], 8, 4)"/></year>
          </xsl:when>
        </xsl:choose>
        <xsl:choose>
          <xsl:when test="contains($numbering, ',s.')">
            <xsl:variable name="item"><xsl:value-of select="substring-before($numbering, ',s.')"/></xsl:variable>
              <issue>
                <xsl:call-template name="trimp">
                  <xsl:with-param name="str" select="$item"/>
                </xsl:call-template>
              </issue>
          </xsl:when>
          <xsl:otherwise>
            <xsl:call-template name="issuedata"/>
          </xsl:otherwise>
        </xsl:choose>
      </xsl:when>
    </xsl:choose>
  </xsl:template>

  <!-- Sivunumerotieto 773-kentän sisällä -->
  <xsl:template match="datafield[@tag='773']/subfield[@code='g']">
    <xsl:variable name="pages">
      <xsl:call-template name="trimp">
        <xsl:with-param name="str" select="substring-after(., 's. ')"/>
      </xsl:call-template>
    </xsl:variable>
    <xsl:choose>
    <!-- Aloitussivu -->
      <xsl:when test="contains($pages, '-')">
        <xsl:variable name="starting-page"><xsl:call-template name="trim"><xsl:with-param name="str" select="substring-before($pages, '-')"/></xsl:call-template></xsl:variable>
        <!-- Viimeinen sivu -->
        <xsl:variable name="last-page"><xsl:call-template name="trimp"><xsl:with-param name="str" select="substring-after($pages, '-')"/></xsl:call-template></xsl:variable>
        <pages><xsl:value-of select="normalize-space($starting-page)"/>-<xsl:value-of select="normalize-space($last-page)"/></pages>
      </xsl:when>
    </xsl:choose>
  </xsl:template>

  <xsl:template name="issuedata">
    <xsl:param name="numbering"/>
    <xsl:variable name="number-and-order" select="substring-after($numbering, ':')"/>
    <xsl:variable name="pages" select="substring-after($numbering, 's.')"/>
    <xsl:variable name="issue_of_year" select="substring-before(substring-after($numbering, ':'), ',')"/>

    <!-- Sivu-muuttujan muoto riippuu kentän sisällöstä -->
    <xsl:variable name="page">
    <xsl:choose>
      <xsl:when test="contains($pages, '-')">
        <xsl:call-template name="trim">
          <xsl:with-param name="str" select="substring-before($pages, '-')"/>
        </xsl:call-template>
      </xsl:when>
      <xsl:when test="contains($number-and-order,'.artikkeli')">
        <xsl:value-of select="
             normalize-space(
                 substring-after(
                     substring-before($number-and-order, '.artikkeli'), ',')
                     )"/>
      </xsl:when>
      <xsl:otherwise>
        <xsl:value-of select="$pages"/>
     </xsl:otherwise>
    </xsl:choose>
    </xsl:variable>

    <volume><xsl:value-of select="substring-before($numbering, '(')"/></volume>
    <issue><xsl:value-of select="$issue_of_year"/>
    </issue>
    <order><xsl:value-of select="$page"/></order>
  </xsl:template>

  <!-- Asiasanat kentässä 650 tai 655-->
  <xsl:template match="datafield[@tag=650 or @tag=655]/subfield[@code='a']">
    <subject>
      <xsl:value-of select="."/>
    </subject>
  </xsl:template>

  <!-- Asiasanat kentässä 653 voivat olla ketjujettuna -->
  <xsl:template match="datafield[@tag=653]">

    <xsl:choose>
      <xsl:when test="count(subfield[@code='a']) > 1">
        <xsl:variable name="chained-entries">
          <xsl:for-each select="subfield[@code='a']">
            <xsl:call-template name="trimp">
              <xsl:with-param name="str" select="."/>
            </xsl:call-template>;
          </xsl:for-each>
        </xsl:variable>
      <subject>
        <xsl:call-template name="trimp">
          <xsl:with-param name="str" select="normalize-space($chained-entries)"/>
        </xsl:call-template>
      </subject>
    </xsl:when>
    <xsl:otherwise>
      <xsl:if test="subfield[@code='a']">
        <subject><xsl:value-of select="subfield[@code='a']"/></subject>
      </xsl:if>
    </xsl:otherwise>
    </xsl:choose>

  </xsl:template>

  <!--Sanaston nimi-->
  <xsl:template match="datafield[@tag=650]/subfield[@code='2']">
    <subject_class>
      <xsl:value-of select="."/>
    </subject_class>
  </xsl:template>

  <!-- Vapaan kuvailun kentät -->
  <xsl:template match="datafield[@tag=600]">
    <!-- Personal name (NR)-->
    <xsl:variable name="person">
      <xsl:call-template name="trimp"><xsl:with-param name="str" select="subfield[@code='a']"/></xsl:call-template>
    </xsl:variable>

    <!-- $t - Title of a work (NR)-->
    <xsl:variable name="title-of-work">
      <xsl:call-template name="trimp">
        <xsl:with-param name="str" select="subfield[@code='t']"/>
      </xsl:call-template>
    </xsl:variable>

    <!-- Henkilön nimi yhdessä teoksen nimen kanssa -->
    <xsl:choose>
      <xsl:when test="string-length($title-of-work)!=0">
        <subject><xsl:value-of select="concat($person,':&#160;',$title-of-work)"/></subject>
      </xsl:when>
      <xsl:otherwise>
        <subject><xsl:value-of select="$person"/></subject>
      </xsl:otherwise>
    </xsl:choose>

  </xsl:template>

  <!-- 610 - Subject Added Entry-Corporate Name (R) or 611 Meeting name-->
  <xsl:template match="datafield[@tag=610 or @tag=611]">

    <xsl:variable name="heading">
      <xsl:call-template name="trimp">
        <xsl:with-param name="str" select="subfield[@code='a']"/>
      </xsl:call-template>
    </xsl:variable>

    <xsl:variable name="subheading">
      <xsl:call-template name="trimp">
        <xsl:with-param name="str" select="subfield[@code='b']"/>
      </xsl:call-template>
    </xsl:variable>

    <xsl:choose>
      <xsl:when test="string-length($subheading)!=0">
        <subject><xsl:value-of select="concat($heading,' - ',$subheading)"/></subject>
      </xsl:when>
      <xsl:otherwise>
        <subject><xsl:value-of select="$heading"/></subject>
      </xsl:otherwise>
    </xsl:choose>

  </xsl:template>

  <!-- Topical term or geographic name entry element (NR)-->
  <xsl:template match="datafield[@tag='650']">

     <subject>
        <xsl:if test="subfield[@code='a']">
          <xsl:value-of select="subfield[@code='a']"/>
        </xsl:if>
        <xsl:if test="subfield[@code='b']">;<xsl:value-of select="subfield[@code='b']"/></xsl:if>
        <!-- $x - General subdivision (R)-->
        <xsl:if test="subfield[@code='x']">
          <xsl:choose>
            <xsl:when test="count(subfield[@code='x']) > 1">
                <xsl:variable name="chained-entries">
                  <xsl:call-template name="trimp">
                    <xsl:with-param name="str" select="datafield[@tag='650']/subfield[@code='x']"/>
                  </xsl:call-template>
                 </xsl:variable>
              <xsl:value-of select="normalize-space($chained-entries)"/>
            </xsl:when>
            <xsl:otherwise>
              <xsl:if test="subfield[@code='x']">;<xsl:value-of select="subfield[@code='x']"/></xsl:if>
            </xsl:otherwise>
          </xsl:choose>
        </xsl:if>
        <!-- $z - Geographic subdivision (R)-->
        <xsl:if test="subfield[@code='z']">;<xsl:value-of select="subfield[@code='z']"/></xsl:if>
        <!-- $y - Chronological subdivision (R)-->
        <xsl:if test="subfield[@code='y']">;<xsl:value-of select="subfield[@code='y']"/></xsl:if>
     </subject>

  </xsl:template>

  <!-- Topical term or geographic name entry element (NR)-->
  <xsl:template match="datafield[@tag='651']">
     <subject>
        <xsl:if test="subfield[@code='a']"><xsl:value-of select="subfield[@code='a']"/></xsl:if>
        <!-- $x - General subdivision (R)-->
        <xsl:if test="subfield[@code='x']">;<xsl:value-of select="subfield[@code='x']"/></xsl:if>
        <!-- $z - Geographic subdivision (R)-->
        <xsl:if test="subfield[@code='z']">;<xsl:value-of select="subfield[@code='z']"/></xsl:if>
        <!-- $y - Chronological subdivision (R)-->
        <xsl:if test="subfield[@code='y']">;<xsl:value-of select="subfield[@code='y']"/></xsl:if>
     </subject>
  </xsl:template>

  <!-- Template for formatting OJS-ready output in second transformation round -->
  <xsl:template name="issues">
    <xsl:param name="all-issues"/>
    <issues>
      <xsl:for-each-group select="$all-issues/issue" group-by="issuedata/volume">
        <xsl:sort select="current-grouping-key()" data-type="number" order="ascending"/>
          <issue published="true" current="false" identification="title">

            <xsl:variable name="journalname">
              <xsl:choose>
                <xsl:when test="issue">
                  <xsl:value-of select="issuedata/journalname"/>
                  <xsl:text> </xsl:text>
                  <xsl:value-of select="issuedata/year"/>
                  <xsl:text>:</xsl:text>
                  <xsl:value-of select="issuedata/issue"/>
                </xsl:when>
                <xsl:otherwise>
                  <xsl:value-of select="issuedata/journalname"/>
                  <xsl:text> </xsl:text>
                  <xsl:value-of select="issuedata/year"/>
                </xsl:otherwise>
              </xsl:choose>
            </xsl:variable>

            <xsl:variable name="locale">
              <xsl:value-of select="article/locale"/>
            </xsl:variable>

            <title locale="{$locale}">
              <xsl:value-of select="$journalname"/>
            </title>
            <volume>
              <xsl:value-of select="current-grouping-key()"/>
            </volume>
            <number>
              <xsl:value-of select="issuedata/issue"/>
            </number>
            <year>
              <xsl:value-of select="issuedata/year"/>
            </year>
            <date_published>
              <xsl:value-of select="article/date_published"/>
            </date_published>
            <section>
              <title locale="{$locale}">Artikkelit</title>
              <abbrev locale="{$locale}">ART</abbrev>
              <!-- Lets output all articles in issue, sorted by order (eg. page number or other ordering information) -->
              <xsl:for-each select="current-group()/article" >
                <xsl:sort select="number(current()/../issuedata/order[1])"/>
                <article>
                  <xsl:copy-of select="title"/>
                  <indexing>
                    <subject>
                      <xsl:for-each select="indexing/subject">
                        <xsl:value-of select="."/>;
                      </xsl:for-each>
                    </subject>
                    </indexing>
                    <xsl:copy-of select="author"/>
                    <xsl:copy-of select="date_published"/>
                    <xsl:copy-of select="pages"/>
                    <xsl:copy-of select="galley"/>
                </article>
              </xsl:for-each>
            </section>
          </issue>
      </xsl:for-each-group>
    </issues>
  </xsl:template>

<xsl:template match="article">
  <xsl:for-each select="current()">

  <xsl:copy-of select="."/>
  </xsl:for-each>
</xsl:template>

<xsl:template match="subject">
  <xsl:value-of select="."/>
</xsl:template>

<!-- Normalization templates from National Library of Finland. -->

<xsl:template name="trim">
   <xsl:param name="str"/>
   <xsl:value-of select="$str"/>
</xsl:template>

 <xsl:template name="replace_all">
   <xsl:param name="str"/>
   <xsl:param name="src"/>
   <xsl:param name="dest"/>
   <xsl:choose>
     <xsl:when test="contains($str, $src)">
       <xsl:value-of select="concat(substring-before($str, $src), $dest)"/>
       <xsl:call-template name="replace_all">
         <xsl:with-param name="str" select="substring-after($str, $src)"/>
         <xsl:with-param name="src" select="$src"/>
         <xsl:with-param name="dest" select="$dest"/>
       </xsl:call-template>
     </xsl:when>
     <xsl:otherwise>
       <xsl:value-of select="normalize-space($str)"/>
     </xsl:otherwise>
   </xsl:choose>
 </xsl:template>

 <xsl:template name="trimp">
   <xsl:param name="str"/>
   <xsl:variable name="lc">
     <xsl:value-of select="substring($str, string-length($str), 1)"/>
   </xsl:variable>
   <xsl:choose>
     <xsl:when test="$lc='-' or $lc='.' or $lc=',' or $lc=';' or $lc=':' or $lc='/' or $lc=' '">
       <xsl:call-template name="trimp">
         <xsl:with-param name="str" select="substring($str, 1, string-length($str)-1)"/>
       </xsl:call-template>
     </xsl:when>
     <xsl:otherwise>
       <xsl:value-of select="$str"/>
     </xsl:otherwise>
   </xsl:choose>
 </xsl:template>

 <!-- Functions from FunctX XSLT Function Library (http://www.xsltfunctions.com/). Licensed under GPl-LGPL-->
 <xsl:function name="functx:substring-after-last" as="xs:string">
   <xsl:param name="arg" as="xs:string"/>
   <xsl:param name="delim" as="xs:string"/>
   <xsl:sequence select="
    replace ($arg,concat('^.*',functx:escape-for-regex($delim)),'')
  "/>
 </xsl:function>

 <xsl:function name="functx:escape-for-regex" as="xs:string" xmlns:functx="http://www.functx.com" >
   <xsl:param name="arg" as="xs:string?"/>
   <xsl:sequence select="
    replace($arg,
            '(\.|\[|\]|\\|\||\-|\^|\$|\?|\*|\+|\{|\}|\(|\))','\\$1')
  "/>
 </xsl:function>

 <!-- Utility template for chained subject entries -->
  <xsl:template name="chained-entries">
       <xsl:param name="str"/>
    ;<xsl:value-of select="str"/>   <xsl:text> </xsl:text>
  </xsl:template>

  <!-- Catch-all template for killing unnecessary output -->
  <xsl:template match="*"/>


</xsl:stylesheet>
