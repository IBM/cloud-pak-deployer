import axios from "axios";
import { Dropdown, InlineNotification, Loading } from "carbon-components-react";
import { useEffect, useState } from "react";
import './Storage.scss'

const Storage = ({cloudPlatform, 
                  setStorage, 
                  storage, 
                  storagesOptions, 
                  setStoragesOptions, 
                  setWizardError,
                  locked,
                  configuration
                }) => {

    const [loadingStorage, setLoadingStorage] = useState(false)
    const [loadStorageErr, setLoadStorageErr] = useState(false)

    useEffect(() => {
      const fetchStorageData = async () => {
        // if (storagesOptions.length === 0) {
        await axios.get('/api/v1/storages/' + cloudPlatform).then(res =>{   
          setLoadingStorage(false)              
          setStoragesOptions(res.data)
          setStorage([res.data[0]])
          setLoadingStorage(false)
          setWizardError(false)
        }, err => {
          setLoadingStorage(false)
          setStorage([])
          setStoragesOptions([])
          setLoadStorageErr(true)    
          setWizardError(true)      
        });          
        // }        
        //updateStorageClass()
      }

      if (locked) {       
        setStoragesOptions([configuration.data.ocp.openshift[0].openshift_storage[0]])
        setStorage([configuration.data.ocp.openshift[0].openshift_storage[0]])
        setWizardError(false)
      } else {
        setLoadingStorage(true)
        fetchStorageData()
      }


      // eslint-disable-next-line
    }, [cloudPlatform])    
    
    const updateStorageClass = (e, storagesOptions) => {
      const selectedStorage = storagesOptions.filter((item)=>(
        item.storage_type === e.selectedItem.storage_type
      ))
      setStorage(selectedStorage)    
    }

    const errorProps = () => ({
      kind: 'error',
      lowContrast: true,
      role: 'error',
      title: 'Unable to get storage class from server.',
      hideCloseButton: false,
    });  
    return (
        <> 
          {loadingStorage && <Loading /> }    

          { loadStorageErr && <InlineNotification className="storage-error"
                {...errorProps()}        
            /> }                
          <div className="storage-title">Storage</div> 
          <div style={{ width: 400 }}>
            <Dropdown disabled={locked}
              id="default"
              label="Please select the storage class"
              items={storagesOptions}
              itemToString={(item) => (item.storage_type )}  
              onChange={(e)=>updateStorageClass(e, storagesOptions)}     
              selectedItem={storage.length === 1 ? storage[0] : storagesOptions[0]}     
            />
          </div>
        </>        
      )
  };

export default Storage;