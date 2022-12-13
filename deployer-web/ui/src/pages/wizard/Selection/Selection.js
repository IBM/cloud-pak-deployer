import axios from "axios";
import { Loading, RadioButton, RadioButtonGroup  } from "carbon-components-react";
import { useEffect, useState } from "react";


const Selection = ({}) => {
    return (
      <>
      
      <div className="infra-title">Deployer Selection</div>        

      <RadioButtonGroup orientation="vertical"
         name="radio-button-group"          
          
         >
         <RadioButton labelText="Configure+Deploy" value="Configure+Deploy" id="0" />
         <RadioButton labelText="Configure+Download" value="Configure+Download" id="1"/>
         <RadioButton labelText="Configure" value="Configure" id="2" />     
      </RadioButtonGroup>

      </>
    );
  };

export default Selection;