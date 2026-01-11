import { RadioButton, RadioButtonGroup } from "carbon-components-react";


const Selection = ({setCpdWizardMode,
                    setSelection,
                    selection

                   }) => {

    const selectOnChange = (e) =>{
      setSelection(e)
      if (e==="Configure") {
        setCpdWizardMode("existing-ocp")
      }
    }

    return (
      <>
      <div className="infra-title">Select</div>
      <RadioButtonGroup orientation="vertical"
         name="radio-button-group"
         onChange={selectOnChange}
         defaultSelected={selection}
         valueSelected={selection}
         >
         <RadioButton labelText="Configure & Deploy" value="Configure+Deploy" id="400" />
         <RadioButton labelText="Configure" value="Configure" id="402" />
      </RadioButtonGroup>

      </>
    );
  };

export default Selection;