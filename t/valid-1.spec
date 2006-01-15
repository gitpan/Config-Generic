# Einzelne Direktiven
SingleDirective Single1 /\w+/
SingleDirective Single2 /\w+/ /\w+/
SingleDirective Single1EtcA /\w+/ etc
SingleDirective Single1EtcB /\w+/ etc
SingleDirective Single1Opt1a /\w+/ optional /\w+/
SingleDirective Single1Opt1b /\w+/ optional /\w+/
SingleDirective Single1OptEtcA /\w+/ optional /\w+/ etc
SingleDirective Single1OptEtcB /\w+/ optional /\w+/ etc

# Multiple Direktiven
MultiDirective Multi1 /\w+/
MultiDirective Multi2 /\w+/ /\w+/
MultiDirective Multi1Etc /\w+/ etc
MultiDirective Multi1Opt1 /\w+/ optional /\w+/
MultiDirective Multi1OptEtc /\w+/ optional /\w+/ etc

# Benötigte Direktiven
MultiDirective Req1 /\d+/
SingleDirective Req2 /\d+/
RequiredDirectives Req1 Req2

# Nicht benötigte Direktiven
MultiDirective NReq1 /\d+/
SingleDirective NReq2 /\d+/

# Gruppen
<MetaSection dummy>
    SingleDirective dummy /\w/
</MetaSection>

SingleSectionRef SingleSection1 dummy
MultiSectionRef MultiSection1 dummy
MultiSectionRef MultiSection2 dummy
NamedSectionRef NamedSection1 dummy
NamedSectionRef NamedSection2 dummy

# Benötigte Gruppen
<SingleSection ReqSingleSection>
    SingleDirective dummy /\w/
</SingleSection>
RequiredSections ReqSingleSection


# Nicht Benötigte Gruppen
<SingleSection NReqSingleSection>
    SingleDirective dummy /\w/
</SingleSection>
