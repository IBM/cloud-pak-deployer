import axios from "axios";
import { Dropdown, InlineNotification, Loading } from "carbon-components-react";
import { useEffect, useState } from "react";
import './Storage.scss'


const Storage = ({cloudPlatform, setStorage, storage, storagesOptions, setStoragesOptions}) => {

    const [loadingStorage, setLoadingStorage] = useState(true)
    const [loadStorageErr, setLoadStorageErr] = useState(false)

    useEffect(() => {
      const fetchStorageData =async () => {
        if (storagesOptions.length === 0) {
            await axios.get('/api/v1/storages/' + cloudPlatform).then(res =>{                 
              setStoragesOptions(res.data)
              setStorage([res.data[0]])
              setLoadingStorage(false)
          }, err => {
              setLoadStorageErr(true)          
          });          
        }
        setLoadingStorage(false)
        //updateStorageClass()
      }
      fetchStorageData()
    }, [])    
    
    const updateStorageClass = (e, storagesOptions) => {
      const selectedStorage = storagesOptions.filter((item)=>(
        item.storage_name === e.selectedItem.storage_name
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
              
          <div className="storage-title">Storage</div> 
          { loadStorageErr && <InlineNotification className="storage-error"
                {...errorProps()}        
            /> } 

          <div style={{ width: 400 }}>
            <Dropdown
              id="default"
              label="Please select the storage class"
              items={storagesOptions}
              itemToString={(item) => (item.storage_name )}  
              onChange={(e)=>updateStorageClass(e, storagesOptions)}     
              selectedItem={storage.length === 1 ? storage[0] : storagesOptions[0]}     
            />
          </div>
        </>        
      )
  };

export default Storage;