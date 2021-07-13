// Import Global Styles
import './src/styles/index.scss';


// Create output language
import Prism from "prism-react-renderer/prism";
(typeof global !== "undefined" ? global : window).Prism = Prism;

Prism.languages.output = {
    dummyToken: {pattern: /$^/},
    outputToken: {pattern:/(.|\n)*/, greedy: true}
}


Prism.languages.error = {
    dummyToken: {pattern: /$^/},
    errorToken: {pattern:/(.|\n)*/, greedy: true}
}

