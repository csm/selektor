//
//  SelektorTests.swift
//  SelektorTests
//
//  Created by Casey Marshall on 11/29/22.
//

import XCTest
@testable import Selektor
import SwiftMsgpackCsm
import SwiftSoup

final class SelektorTests: XCTestCase {

    override func setUpWithError() throws {
        // Put setup code here. This method is called before the invocation of each test method in the class.
    }

    override func tearDownWithError() throws {
        // Put teardown code here. This method is called after the invocation of each test method in the class.
    }

    func testExample() throws {
        // This is an example of a functional test case.
        // Use XCTAssert and related functions to verify your tests produce the correct results.
        // Any test you write for XCTest can be annotated as throws and async.
        // Mark your test throws to produce an unexpected failure when your test encounters an uncaught error.
        // Mark your test async to allow awaiting for asynchronous code to complete. Check the results with assertions afterwards.
    }

    func testPerformanceExample() throws {
        // This is an example of a performance test case.
        self.measure {
            // Put the code you want to measure the time of here.
        }
    }
    
    func testEncodeResult() throws {
        let results: [Result] = [
            .IntegerResult(integer: 42),
            .FloatResult(float: 3.14159),
            .LegacyFloatResult(float: 3.14159),
            .PercentResult(value: 50),
            .LegacyPercentResult(value: 50),
            .StringResult(string: "test"),
            .ImageResult(imageData: "abc".data(using: .utf8)!)
        ]
        try results.forEach { result in
            let encoder = MsgPackEncoder()
            let encoded = try encoder.encode(result)
            let decoder = MsgPackDecoder()
            let decoded = try decoder.decode(Result.self, from: encoded)
            XCTAssertEqual(result, decoded)
        }
    }

    /*
    func testWebkitQuerySelector() async throws {
        let _ = WKWebViewConfiguration()
        let document = try await withCheckedThrowingContinuation {
            continuation in
            Erik.visit(url: URL(string: "https://www.duckduckgo.com")!) { result, error in
                if let result = result {
                    continuation.resume(returning: result)
                } else {
                    continuation.resume(throwing: error!)
                }
            }
        }
        let selected = document.querySelectorAll(".badge-link__title")
        print("selected: \(selected)")
    }
     */
    
    let html = """
<!DOCTYPE html>
<html lang="en">
<head>
<meta charset=utf-8 />
<meta http-equiv="X-UA-Compatible" content="IE=edge">

<title>Oblique Strategies</title>

<meta http-equiv="Content-Type" content="text/html; charset=utf-8" />
<meta name="DC.description" content="Over one-hundred worthwhile dilemmas by Briano Eno and Peter Schmidt" />
<meta name="DC.creator" content="Jen Strickland - http://inkpixelspaper.com" />
<meta name="DC.subject" content="Oblique Strategies, Brian Eno, Peter Schmidt, Creativity, Creative Blocks" />
<meta name="keywords" content="Oblique Strategies, Brian Eno, Peter Schmidt, Creativity, Creative Blocks" />
<meta name="viewport" content="width=device-height"/>

<link rel="shortcut icon" href="favicon.ico" type="image/ico" />

<!--<link rel="stylesheet" type="text/css" href="/stylesheets/main.css" title="default" />-->
<style>
/* reset css */
/* http://meyerweb.com/eric/tools/css/reset/ */
/* v1.0 | 20080212 */

html, body, div, span, applet, object, iframe,
h1, h2, h3, h4, h5, h6, p, blockquote, pre,
a, abbr, acronym, address, big, cite, code,
del, dfn, em, font, img, ins, kbd, q, s, samp,
small, strike, strong, sub, sup, tt, var,
b, u, i, center,
dl, dt, dd, ol, ul, li,
fieldset, form, label, legend,
table, caption, tbody, tfoot, thead, tr, th, td {
margin:0;
padding:0;
border:0;
outline:0;
font-size:100%;
vertical-align:baseline;
background:transparent;
}

body {
line-height:1;
}

ol, ul {
list-style:none;
}

blockquote, q {
quotes:none;
}

blockquote:before,
blockquote:after,
q:before, q:after {
content:'';
content:none;
}

/* remember to define focus styles! */
:focus {
outline:0;
}

/* remember to highlight inserts somehow! */
ins {
text-decoration:none;
}

del {
text-decoration:line-through;
}

/* tables still need 'cellspacing="0"' in the markup */
table {
border-collapse:collapse;
border-spacing:0;
}

/* site css */

article,aside,dialog,figure,footer,header,hgroup,main,menu,nav,section    { display:block; }

* { margin:0; padding:0; }
body { background:#333 url(../images/banner-bkgd.jpg) repeat -80% 0; color:#555; font-family:"Baskerville Old Face D", Georgia, "Times New Roman", Times, serif; font-weight:normal; line-height:1.25; text-shadow: 0.02em 0.02em 0.05em #222; }
main { margin:0 auto; width:90%; }
header {  height:3em; margin:0; padding:; text-align:center; }
article { height:18em; margin:35px auto 150px auto; width:100%; }
footer { clear:both; font-family:"Lucida Sans Unicode", "Lucida Grande", sans-serif; font-size:.8em; margin:1em auto; padding:0; text-align:center; width:90%; }

a    { color:#555;   }
a:hover    { background:#734f11; background:rgba(166,125,0,.3); color:#fff; }
a:active    { color:#fc0; }

h1,h1 a    { background:transparent; color:#c90; font-size:1.5em; letter-spacing:1px; margin:.5em 0 0 0; text-align:center; text-decoration:none; text-shadow: 0.05em 0.05em 0.1em #000; text-transform:uppercase; }

h2 { background:#fff url(../images/bkgd.jpg) top left repeat; border:1px solid black; clear:both; color:#000; color:rgba(5,5,5,0.7); display:block; font-family:Georgia, "Times New Roman", Times, serif; font-size:2.75em; min-height:3em; margin:auto; padding:1em; text-align:center; width:70%; /*enhancements*/ -webkit-border-radius:0.9em; -moz-border-radius:0.9em; -webkit-box-shadow: 2px 2px 2em #000;
box-shadow: 2px 2px 2px #222; }

p { font-size:.9em; }
img    { border:0; }
cite    { font-size:.5em; }
.amp { font-family:Baskerville, "Goudy Old Style", "Palatino", "Book Antiqua", serif; font-weight:normal; font-style:italic; font-size:1.1em; }
.note { background-color:#f93; }


</style>

<!--[if IE]><script src="http://html5shiv.googlecode.com/svn/trunk/html5.js"></script><![endif]-->
</head>

<body id="">

<main role="main">

<header role="banner">
<h1><a href="index.php">Oblique Strategies</a></h1>
</header>

<article>
<h2>A very small object &mdash; Its centre.</h2>


</article>

<footer role="contentinfo">
<p>Copyright &copy; 2022 Brian Eno <span class="amp">&amp;</span> Peter Schmidt. All rights reserved. </p>
<p>Permission pending &mdash; I hope. An email has been forwarded to him.</p>
<p>Design <span class="amp">&amp;</span> Development by <a href="http://inkpixelspaper.com">Ink Pixels Paper</a></p>
</footer>

</main>
</body>
</html>
"""
    
    func testCssSelector() throws {
        let doc = try SwiftSoup.parse(html)
        let elements = try doc.select("article h2")
        XCTAssertGreaterThan(elements.count, 0)
        XCTAssertEqual(try elements[0].html(), "A very small object — Its centre.")
    }
    
    /*func testHtmlAttributedString() throws {
        
        let node = try HTML(html: html.data(using: .utf8)!, encoding: .utf8)
        let element = node.css("article h2", namespaces: nil).first!
        print("got element: \(element), element text: \(element.toHTML)")
        let attributedString = element.attributedString
        print("created attributedstring: \(attributedString)")
        let htmlData = try attributedString.data(from: NSMakeRange(0, attributedString.length), documentAttributes: [NSAttributedString.DocumentAttributeKey.documentType: NSAttributedString.DocumentType.html])
        print("created htmlData: \(String(data: htmlData, encoding: .utf8))")
        let attributedString2 = try NSAttributedString(data: htmlData, options: [.documentType: NSAttributedString.DocumentType.html, .characterEncoding: String.Encoding.utf8.rawValue], documentAttributes: nil)
        print("equal? \(attributedString == attributedString2)")
    }*/
}
