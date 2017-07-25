<?xml version="1.0"?>
<xsl:stylesheet 
  version="1.0"
  xmlns:xsl="http://www.w3.org/1999/XSL/Transform"
>

<xsl:output method="text" />
<xsl:template match="/">
  <xsl:text>{| class="wikitable sortable" style="width:85%"&#x0D;&#x0A;</xsl:text>
  <xsl:text>! style="width: 25%" align="center" | Module&#x0D;&#x0A;</xsl:text>
  <xsl:text>! style="width: 15%" align="center" | Type&#x0D;&#x0A;</xsl:text>
  <xsl:text>! style="width: 15%" align="center" | Documentation&#x0D;&#x0A;</xsl:text>
  <!--  <xsl:text>! style="width: 20%" align="center" | Name&#x0D;&#x0A;</xsl:text> -->
  <!--  <xsl:text>! style="width: 15%" align="center" | Version&#x0D;&#x0A;</xsl:text> -->
  <xsl:text>! align="center" | Description&#x0D;&#x0A;</xsl:text>
  <xsl:apply-templates select="root/module" />
  <xsl:text>|}</xsl:text>
</xsl:template>

<xsl:template match="module">
  <xsl:text>|-&#x0D;&#x0A;</xsl:text>

  <!-- Output Module column -->
  <xsl:text>| align="center" | [</xsl:text>
  <xsl:value-of select="normalize-space(./site)" />
  <xsl:text> </xsl:text>
  <xsl:value-of select="normalize-space(./module_name)" />
  <xsl:text>]</xsl:text>
  <xsl:text>&#x0D;&#x0A;</xsl:text>
  
  <!-- Output type column -->
  <xsl:text>| align="center" | </xsl:text>
  <xsl:value-of select="normalize-space(./type)" />
  <xsl:text>&#x0D;&#x0A;</xsl:text>
  
  <!-- Output wiki page column -->
  <xsl:text>| align="center" | </xsl:text>
  <xsl:if test="string-length(normalize-space(./wikipage))>0">
  <xsl:text>[[</xsl:text>
  <xsl:value-of select="normalize-space(./wikipage)" />
  <xsl:text>]]</xsl:text>
  </xsl:if>
  <xsl:text>&#x0D;&#x0A;</xsl:text>


  <!-- Output Nom column -->
  <!-- <xsl:text>| align="center" | [</xsl:text>
  <xsl:value-of select="normalize-space(./site)" />
  <xsl:text> </xsl:text>
  <xsl:value-of select="normalize-space(./app_name)" />
  <xsl:text>]</xsl:text>
  <xsl:text>&#x0D;&#x0A;</xsl:text> -->
  
  <!-- Output Version column -->
  <!--
  <xsl:text>| align="center" | </xsl:text>
  <xsl:value-of select="normalize-space(./version)" />
  <xsl:text>&#x0D;&#x0A;</xsl:text> -->

  <!-- Output Description column -->
  <xsl:text>| </xsl:text>
  <xsl:text>&lt;div class="mw-collapsible mw-collapsed" style="white-space: pre-line;"&gt;</xsl:text>
    <xsl:call-template name="output-line-break" />
    <xsl:value-of select="normalize-space(./help)" />
    <xsl:call-template name="output-line-break" />
    <xsl:text>'''Prerequisites:''' </xsl:text>
    <xsl:value-of select="normalize-space(./prereq)" />

    <!--
    <xsl:call-template name="output-line-break" />
    <xsl:text>'''Conflicts :''' </xsl:text>
    <xsl:value-of select="normalize-space(./conflict)" />
    -->

    <!--  <xsl:call-template name="output-line-break" />
    <xsl:text>'''Load :''' </xsl:text>
    <xsl:value-of select="normalize-space(./autoload)" />
    -->
    <xsl:call-template name="output-line-break" />
    <xsl:text>'''Description:''' </xsl:text>
    <xsl:value-of select="normalize-space(./whatis)" />
  <xsl:text>&lt;/div&gt;</xsl:text>
  <xsl:text>&#x0D;&#x0A;</xsl:text>
</xsl:template>

<xsl:template name="output-line-break">
  <xsl:text>&lt;br /&gt;</xsl:text>
</xsl:template>

<xsl:template match="@*|text()|processing-instruction()|comment()" />

</xsl:stylesheet>
