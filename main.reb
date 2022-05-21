Rebol [
    type: module
    author: "Graham Chiu"
    exports: [
        add-form ; puts JS form into DOM
        add-content ; adds content to the form
        choose-drug ; pick drug from a selection
        clear-form ; clears the script
        clear-rx ; clears the drugs but leaves patient
        cdata ; the JS that will be executed
        expand-latin ; turns abbrevs into english
        grab-creds ; gets credentials
        manual-entry ; asks for patient demographics
        new-rx ; start a new prescription
        parse-demographics ; extracts demographics from clinical portal details
        rx ; starts the process of getting a drug schedule
        rxs ; block of rx
        set-doc ; fills the wtemplate with current doc
        write-rx ; sends to docx
        street town city
        docname
        docregistration
    ]
]

import @popupdemo
root: https://github.com/gchiu/midcentral/blob/main/drugs/
raw_root: https://raw.githubusercontent.com/gchiu/midcentral/main/drugs/ ; removed html etc

slotno: 6
; rx-template: https://github.com/gchiu/midcentral/raw/main/rx-template-docx.docx ; can't use due to CORS
rx-template: https://metaeducation.s3.amazonaws.com/rx-6template-docx.docx
rxs: []
firstnames: surname: dob: title: nhi: rx1: rx2: rx3: rx4: rx5: rx6: street: town: city: docname: docregistration: _
wtemplate: _

dgh: {This Prescription meets the requirement of the Director-General of Health’s waiver of March 2020 for prescriptions not signed personally by a prescriber with their usual signature}

for-each site [
    https://cdnjs.cloudflare.com/ajax/libs/docxtemplater/3.29.0/docxtemplater.js
    https://unpkg.com/pizzip@3.1.1/dist/pizzip.js
    ; https://cdnjs.cloudflare.com/ajax/libs/jszip/2.6.1/jszip.js
    https://cdnjs.cloudflare.com/ajax/libs/FileSaver.js/1.3.8/FileSaver.js
    https://unpkg.com/pizzip@3.1.1/dist/pizzip-utils.js
    ; https://cdnjs.cloudflare.com/ajax/libs/jszip-utils/0.0.2/jszip-utils.js
][
    js-do site
]

; do %storage.reb
; do http://hostilefork.com/media/shared/replpad-js/storage.reb ; loaded implicitly

js-do {window.loadFile = function(url,callback){
        PizZipUtils.getBinaryContent(url,callback);
    };
}

cdata: {window.generate = function() {
        loadFile("$docxtemplate",
    function(error,content){
            if (error) { throw error };
            var zip = new PizZip(content);
            // var doc=new window.docxtemplater().loadZip(zip)
        var doc = new window.docxtemplater(zip, {
                        paragraphLoop: true,
                        linebreaks: true,
                    });
            try {
                // render the document (replace all occurences of {first_name} by John, {last_name} by Doe, ...)
                doc.render({
            $template
        });
            }
            catch (error) {
                var e = {
                    message: error.message,
                    name: error.name,
                    stack: error.stack,
                    properties: error.properties,
                }
                console.log(JSON.stringify({error: e}));
                // The error thrown here contains additional information when logged with JSON.stringify (it contains a property object).
                throw error;
            }
            var out=doc.getZip().generate({
                type:"blob",
                mimeType: "application/vnd.openxmlformats-officedocument.wordprocessingml.document",
            }) //Output the document using Data-URI
            saveAs(out,"$prescription.docx")
        })
    };
    generate()
}

set-doc: does [
    wtemplate: copy template
    wtemplate: reword wtemplate reduce ['docname docname 'docregistration docregistration 'signature docname] ; 'date now/date]
    ; probe wtemplate
]

grab-creds: func [ <local> docnames docregistrations] [
    cycle [
        docnames: ask ["Enter your name as appears on a prescription:" text!]
        docregistrations: ask ["Enter your prescriber ID number:" integer!]
        response: lowercase ask ["Okay?" text!]
        if find ["yes" "y"] response [
            set 'docname :docnames
            set 'docregistration :docregistrations
            break
        ]
    ]
    set-doc
    ; probe wtemplate
    write %/credentials.reb mold reduce [docname docregistration]
    return
]

expand-latin: func [sig [text!]
    <local> data
][
    data: [
        "QD" "once daily"
        "QW" "once weekly"
        "BID" "twice daily"
        "TDS" "three times daily"
        "mane" "in the morning"
        "nocte" "at night"
        "PC" "with food"
        "AC" "before food"
        "SQ" "subcutaneous"
    ]
    for-each [abbrev expansion] data [
        replace/all sig unspaced [space abbrev space] unspaced [space expansion space]
        replace/all sig unspaced [space abbrev newline] unspaced [space expansion newline]
    ]
    return sig
]

add-form: does [
    show-dialog/size {<div id="board" style="width: 400px"><textarea id="script" cols="80" rows="80"></textarea></div>} 480x480
]

clear-form: does [
    js-do {document.getElementById('script').innerHTML = ''}
    set-doc
]

add-content: func [txt [text!]
][
    txt: append append copy txt newline newline
    js-do [{document.getElementById('script').innerHTML +=} spell @txt]
]

choose-drug: func [scheds [block!]
    <local> num choice output rx sig mitte drugname drug dose
][
    num: length-of scheds
    choice: ask ["Which schedule to use?" integer!]
    if choice = 0 [return]
    if choice <= num [
        print output: expand-latin pick scheds choice
        add-content output
        append rxs output
        return
    ]
    ; out of bounds
    output: pick scheds 1
    drugname: _
    ; first off, get any drugs that start with a digit eg. 6-Mercaptopurine
    parse output [copy drugname some digit copy output to end]
    if empty? drugname [
        ; not a drug that starts with a digit
        drugname: copy ""
    ] ; otherwise drugname = "6" etc
    ; now get the rest of the drugname
    parse output [copy drug to digit to end (append drugname drug)]
    ; so we now have the drugname
    ; so let's ask for the new dose
    cycle [
        dose: ask compose [(spaced ["New Dose for" drugname]) text!]
        sig: ask ["Sig:" text!]
        mitte: ask ["Mitte:" text!]
        response: copy/part lowercase ask ["Okay?" text!] 1
        if response = "y" [break]
    ]
    output: expand-latin spaced [drugname dose "^/Sig:" sig "^/Mitte:" mitte]
    add-content output
    append rxs output
    return
]

comment {

ASurname, Basil Phillip (Mr)

BORN16-Aug-1925 (96y)GENDER Male

NHIABC1234



    

Address  29 Somewhere League, Middleton, NEW ZEALAND, 4999

Home  071234567
}

whitespace: charset [#" " #"^/" #"^M" #"^J"]
alpha: charset [#"A" - #"Z" #"a" - #"z"]
digit: charset [#"0" - #"9"]
nhi-rule: [3 alpha 4 digit]

template: {
    surname: '$surname',
    firstnames: '$firstnames',
    title: '$title',
    dob: '$dob',
    street: '$street',
    town: '$town',
    city: '$city',
    nhi: '$nhi',
    phone: '$phone',
    rx1: `$rx1`,
    rx2: `$rx2`,
    rx3: `$rx3`,
    rx4: `$rx4`,
    rx5: `$rx5`,
    rx6: `$rx6`,
    signature: '$signature',
    date: '$date',
    docname: '$docname',
    docregistration: '$docregistration',
    dgh: `$dgh`,
}

parse-demographics: func [
    <local> data
][
    demo: ask ["Paste in demographics from CP" text!]
    parse demo [
        [maybe some whitespace]
        copy surname to ","
        thru space [maybe some space]
        [copy firstnames to "("] (trim/head/tail firstnames)
        thru "(" copy title to ")"  ; `title: between "(" ")"`
        thru "BORN" copy dob to space
        thru "(" copy age to ")"    ; `age: into between "(" ")" integer!`
        thru "GENDER" maybe some space copy gender some alpha
        thru "NHI" copy nhi nhi-rule
        thru "Address" [maybe some whitespace] copy street to ","
        thru "," [maybe some whitespace] copy town to ","
        thru "," [maybe some whitespace] copy city to ","
        [thru "Home" | thru "Mobile" ] [maybe some whitespace]
        copy phone some digit
        to end
    ]
comment {
    dump surname
    dump firstnames
    dump title
    dump dob
    dump gender
    dump nhi
    dump street
    dump town
    dump city
    dump phone
}
    clear-form
    data: unspaced [ surname "," firstnames space "(" title ")" space "DOB:" space dob space "NHI:" space nhi newline street newline town newline city newline newline]
    wtemplate: reword wtemplate reduce ['firstnames firstnames 'surname surname 'title title 'street street 'town town 'city city 'phone phone
        'dob dob 'nhi nhi
        'prescription nhi
    ]
    ; probe wtemplate
    write to file! unspaced ["/" nhi %.reb] mold compose [
        nhi: (nhi)
        title: (title)
        surname: (surname)
        firstnames: (firstnames)
        dob: (dob)
        street: (street)
        town: (town)
        city: (city)
        phone: (phone)
        gender: (gender)
    ]

    add-content data
    print unspaced ["saved " "%/" nhi %.reb ]
]

manual-entry: func [
    <local> filename filedata response
][
    print "Enter the following details:"
    nhi: uppercase ask ["NHI:" text!]
    if word? exists? filename: to file! unspaced [ "/" nhi %.reb][
        filedata: load to text! read filename
        filedata: filedata.1
        title: filedata.title
        surname: filedata.surname
        firstnames: filedata.firstnames
        dob: filedata.dob
        street: filedata.street
        town: filedata.town
        city: filedata.city
        phone: filedata.phone
        gender: filedata.gender

        ; dump filedata
    ] else [
        cycle [
            title: uppercase ask ["Title:" text!]
            surname: ask ["Surname:" text!]
            firstnames: ask ["First names:" text!]
            dob: ask ["Date of birth:" date!]
            street: ask ["Street Address:" text!]
            town: ask ["Town:" text!]
            city: ask ["City:" text!]
            phone: ask ["Phone:" text!]
            gender: ask ["Gender:" text!]
            response: lowercase ask ["OK?" text!]

            if response.1 = #y [break]
        ]
    ]
    dump surname
    dump firstnames
    dump title
    dump dob
    dump gender
    dump nhi
    dump street
    dump town
    dump city
    dump phone
    data: unspaced [ surname "," firstnames space "(" title ")" space "DOB:" space dob space "NHI:" space nhi newline street newline town newline city newline newline]
    wtemplate: reword wtemplate reduce ['firstnames firstnames 'surname surname 'title title 'street street 'town town 'city city 'phone phone
        'dob dob 'nhi nhi
        'prescription nhi
    ]
    ; probe wtemplate
    write to file! unspaced ["/" nhi %.reb] mold compose [
        nhi: (nhi)
        title: (title)
        surname: (surname)
        firstnames: (firstnames)
        dob: (dob)
        street: (street)
        town: (town)
        city: (city)
        phone: (phone)
        gender: (gender)
    ]

    add-content data
    print unspaced ["saved " "%/" nhi %.reb ]
]

rx: func [ drug [text! word!]
    <local> link result c err counter line drugs
][
    drug: form drug
    ; search for drug in database, get the first char
    c: form first drug
    link: to url! unspaced [raw_root c %.reb]
    dump link
    if error? err: trap [data: load link] [
        print spaced ["This page" link "isn't available, or, has a syntax error"]
    ] else [
        if drug.2 = #"*" [
            ; asking for what drugs are available
            counter: 0 line: copy [] drugs: copy []
            for-each item data [
                if text? item [append line item]
                if block? item [
                    counter: me + 1
                    insert head line form counter
                    print line
                    clear head line
                    append drugs lastitem
                ]
                lastitem: copy item
            ]
            response: ask compose [(join "0-" counter) integer!]
            if all [response > 0 response <= counter][
                drug: pick drugs response
            ] else [
                return
            ]
        ]
        if null? result: switch drug data [; data comes from import link
            print spaced ["Drug" drug "not found in database."]
            print ["You can submit a PR to add them here." https://github.com/gchiu/midcentral/tree/main/drugs ]
        ] else [
            if 0 < len: length-of result [
                print newline
                for i len [print form i print result.:i print newline]
                choose-drug result
            ]
        ]
    ]
]

clear-rx: func [ <local> data ][
    clear-form
    probe wtemplate
    ?? nhi
    ?? firstnames
    data: unspaced [ surname "," firstnames space "(" title ")" space "DOB:" space dob space "NHI:" space nhi newline street newline town newline city newline newline]
    wtemplate: reword wtemplate reduce ['firstnames firstnames 'surname surname 'title title 'street street 'town town 'city city 'phone phone
        'dob dob 'nhi nhi
        'prescription nhi
    ]
    probe wtemplate
    add-content data
    ; add-content unspaced [ surname "," firstnames space "(" title ")" space "DOB:" space dob space "NHI:" space nhi newline street newline town newline city newline newline]
    clear rxs
    print "Ready for another Rx"
]

write-rx: func [
    <local> codedata response
] [
    ; append/dup rxs space slotno
    codedata: copy cdata
    replace codedata "$template" wtemplate
    replace codedata "$docxtemplate" rx-template
    replace codedata "$prescription" unspaced [nhi "_" now/date]
    codedata: reword codedata reduce ['rx1 rxs.1 'rx2 any [rxs.2 space] 'rx3 any [rxs.3 space] 'rx4 any [rxs.4 space] 'rx5 any [rxs.5 space] 'rx6 any [rxs.6 space]]
    codedata: reword codedata reduce compose ['date (spaced [now/date now/time])]
    response: lowercase ask ["For email?" text!]
    codedata: reword codedata reduce compose ['dgh (if response.1 = #"y" [dgh] else [" "])]
    ; probe cdata
    js-do codedata
]

new-rx: does [
    if empty? docname [
        grab-creds
    ]
    rxs: copy []
    set-doc
    add-form
    response: lowercase ask ["Paste in Patient Demographics from Clinical Portal? (y/n)" text!]
    if response.1 = #y [
        parse-demographics
    ] else [
        manual-entry
    ]
    print {"Use Rx" to add a drug to prescription}
]

; print "checking for %/credentials.reb"

if word? exists? %/credentials.reb [
    creds: load read %/credentials.reb
    docname: creds.1.1
    docregistration: creds.1.2
    set-doc
    print ["Welcome" docname]
]

new-rx
