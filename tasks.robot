# +
*** Settings ***
Documentation   A robot built for the Robotcorp Level II Certification
...             Saves down the orders.csv into the folder with the tasks.robot file
...             Orders a single robot based on the orders.csv file
...             Previews the order of the robot and saves the image
...             Orders the robot and saves the receipt 
...             Creates a PDF of the receipt and the robot image
...             Loops through the full orders.csv file repeating the prior four steps 
...             Creates a zip file of all of the PDFs

Library         RPA.Browser.Selenium
Library         RPA.HTTP
Library         RPA.Tables
Library         RPA.RobotLogListener
Library         RPA.PDF
Library         RPA.Archive
Library         RPA.Dialogs
Library         RPA.FileSystem
Library         RPA.Robocloud.Secrets
Resource        finance_task.resource
# -


*** Keywords ***
Ask User Which Program They Want To Run
    Add heading       Which Program Do You Want To Run?
    Add radio buttons    
        ...    name=program_choice
        ...    options=Weekly Order Input,Build A Robot,Exit
        ...    default=Exit
        ...    label=Program choice
    ${dialog}=    Show dialog   title=Menu
    ${result}=      Wait dialog    ${dialog}
    [Return]    ${result.program_choice}

*** Keywords ***
Open Browser to RobotSpareBin Website
    Open Available Browser  https://robotsparebinindustries.com/#/robot-order

*** Keywords ***
Accept the TOU
    Click Button When Visible    //button[@class="btn btn-dark"]

*** Keywords ***
Download Orders CSV
    Download    https://robotsparebinindustries.com/orders.csv  overwrite=True

*** Keywords ***
Read CSV As Table
    ${orders_data}=    Read table from CSV    orders.csv    header=True
    [Return]    ${orders_data}

*** Keywords ***
Click Preview Button
    Click Button    id:preview

*** Keywords ***
Click Order Button
    Click Button    id:order

*** Keywords ***
Click Order Another Robot
    Click Button    id:order-another

*** Keywords ***
Save Order HTML
    Wait Until Element Is Visible    id:receipt
    ${receipt}=    Get Element Attribute    id:receipt    outerHTML
    [Return]    ${receipt}

*** Keywords ***
Save Preview Image
    [Arguments]    ${order_number}
    Wait Until Element Is Visible    id:robot-preview
    #Noticed a scenario where the preview locator was visable but the images were not fully loading resulting in incomplete screenshots
    Wait Until Element Is Visible    css:img[alt="Head"]
    Wait Until Element Is Visible    css:img[alt="Body"]
    Wait Until Element Is Visible    css:img[alt="Legs"]
    #Setting the output directory directly for the screenshot; Also saving them in a sub-directory to ensure they are not part of the ZIP file
    #The default in Robocorp Lab appears to be a temp file which returns a full path
    #while the default in VS is EMBED which does not return a path
    ${robot_preview}=    Capture Element Screenshot    id:robot-preview-image    	${OUTPUTDIR}${/}screenshots${/}robot-order-${order_number}.png
    [Return]    ${robot_preview}

*** Keywords ***
Create PDF From Order HTML And Preview Image
    [Arguments]     ${order_receipt}    ${robot_image}    ${order_number}   
    Html To Pdf    ${order_receipt}    ${CURDIR}${/}output${/}order_${order_number}.pdf
    ${image_file}=    Create List   ${robot_image}
    Add Files To Pdf    ${image_file}      ${CURDIR}${/}output${/}order_${order_number}.pdf   append=True

*** Keywords ***
If Error Appears
    [Arguments]    ${locator}
    #Loop is needed here to check for mulitple error occurring back to back
    FOR    ${i}    IN RANGE    9999999
        ${error_on_page}=    Does Page Contain Element    ${locator}    count=1
        IF      ${error_on_page}==True
        Mute Run On Failure    Click Preview Button
        Run Keyword And Ignore Error    Click Preview Button
        Mute Run On Failure    Click Order Button
        Run Keyword And Ignore Error    Click Order Button
        END
        Exit For Loop If    ${error_on_page}==False
    END


*** Keywords ***
Complete Single Order
    [Arguments]     ${order_data}
    Select From List By Value      head    ${order_data}[Head]
    Select Radio Button    body    ${order_data}[Body]
    #Input Text    css:#root > div > div.container > div > div.col-sm-7 > form > div:nth-child(3) > input    ${order_data}[Legs]
    Input Text    css:input[placeholder="Enter the part number for the legs"]    ${order_data}[Legs]
    Input Text    id:address    ${order_data}[Address]
    [Return]    ${order_data}[Order number]

*** Keywords ***
Input Orders Into RobotSpareBin Website
    [Arguments]     ${orders_data}
    FOR    ${order_data}    IN    @{orders_data}
        ${order_number}=    Complete Single Order   ${order_data}
        #Preview button must be clicked before the Order Button to generate the robot image
        Click Preview Button
        Click Order Button
        If Error Appears    css:div[role="alert"]
        #Saving the image and Order PDF once on the order page
        ${robot_image}=    Save Preview Image    ${order_data}[Order number]
        ${order_receipt}=    Save Order HTML
        Create PDF From Order HTML And Preview Image    ${order_receipt}    ${robot_image}      ${order_number}
        Click Order Another Robot
        Accept the TOU
    END

*** Keywords ***
Add to ZIP File
    [Arguments]     ${location}
    Add to Archive  ${location}     orders.zip

*** Keywords ***
Create ZIP of PDFs
    Archive Folder With Zip    ${CURDIR}${/}output    ${CURDIR}${/}output${/}orders.zip     include=order_*

*** Keywords ***
Exit Message
    ${message}=     Get Secret    exitmessage
    Add icon      Success
    Add heading   ${message}[message]
    Add submit buttons    buttons=Ok    default=Ok
    ${result}=    Run dialog

*** Keywords ***
Fail Exit Message
    #Include this in error catching in the future
    ${message}=     Get Secret    failexitmessage
    Add icon      Failure
    Add heading   ${message}[message]
    Add submit buttons    buttons=Ok    default=Ok
    ${result}=    Run dialog

*** Tasks ***
Order Robots and Create PDF Receipts Or Input Weekly Sales Numbers
    ${user_choice}=    Ask User Which Program They Want To Run
    #Additional choices to the user could include asking them how many robot orders they want to submit (1 - 20)
    #Additional choices can also include asking the user if they want to delet files from the output folder before the next run
    #Additional versions can include a loop for the menu and an about option to indicate version and author information
    
    IF    "${user_choice}" == "Build A Robot"
        Open Browser to RobotSpareBin Website       #Do I want to eventually run this in headless mode for the cloud container?
        Accept the TOU
        Download Orders CSV
        ${orders}=    Read CSV As Table
        Input Orders Into RobotSpareBin Website     ${orders}
        Create ZIP of PDFs
        Close Browser       #Teardown does not work inside the IF statement; To be addressed in later versions
    ELSE IF     "${user_choice}" == "Weekly Order Input"
        Open The Intranet Website
        Log In
        Download The Excel File
        Fill The Form Using The Data From The Excel File
        Collect The Results
        Export The Table As A PDF
        Log Out And Close The Browser
    ELSE IF     "${user_choice}" == "Exit"
        Exit Message
        Log     "User has chosen to Exit the program"
    ELSE
        Fail Exit Message
        Log    "Program has exited by being closed or due to an error condition"
    END

