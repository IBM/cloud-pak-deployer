import { Dropdown, RadioButton, RadioButtonGroup, TextInput } from "carbon-components-react";
import { useState } from "react";
import './Storage.scss'

const items = [
    {
      id: 'OCS',
      text: 'ocs-storage',
    },
    {
      id: 'NFS',
      text: 'nfs-storage',
    },
  ];

const Storage = () => {

    const [currentIndex, setcurrentIndex] = useState(0)
    return (
        <>
          <div className="storage-title">Storage</div> 
          <div style={{ width: 400 }}>
            <Dropdown
              id="default"
              label="Please select the storage class"
              items={items}
              itemToString={(item) => (item ? item.text : '')}
              
            />
          </div>
        </>
        
      )
  };

export default Storage;