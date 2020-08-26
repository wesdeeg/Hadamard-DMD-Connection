clear
close all
tic
A = readcell('first_48_batch_edited.txt');
num_of_images = 0;
num_of_bytes = 0;
for heck = 1:size(A, 1)
    % Here, we want to isolate out the LUT config commands for the number
    % of images, and the upload commands to determine the number of bytes
    % of data sent
    if strcmp(A{heck, 1},'MBOX_DATA') == 1
        num_of_images = num_of_images + 1;
    elseif strcmp(A{heck, 1},'PATMEM_LOAD_INIT_MASTER') == 1
        hex = strcat(num2str(A{heck, 7}), num2str(A{heck, 6}), num2str(A{heck, 5}), num2str(A{heck, 4}));
        num_of_bytes = num_of_bytes + hex2dec(hex);
    end
end
% The commands necessary are
% 1: change the display mode to pattern-on-the fly (1)
% 2: stop any pre-existing patterns (1)
% 3: configure the LUT (number of images)
% 4: configure the pattern (1)
% 5: initialize the pattern upload (1)
% 6: upload the pattern (fuck + 1)
% 7: configure the pattern (1)
% 8: start the pattern (1)

% Adjusted to just fit with the text file size
noc = size(A, 1);
len = size(A, 2);
command_array{noc, len} = [];
for i = 1:noc
    % Here, trying to form the header correctly, so for each possible TI
    % header, we correlate that to the correct HEX input the matlab code
    % provides for us, keeping up the numbering of the commands sent
    % forth.
    if strcmp(A{i, 1},'DISP_MODE') == 1
        % Method below does not work to store header inside of array
        command_string = {40,i,3,0,'1B','1A'};
        command_array(i,:) = horzcat(command_string, A(i,2:len - 5));
    elseif strcmp(A{i, 1},'MBOX_DATA') == 1
        command_string = {40,i,'E',0,34,'1A'};
        command_array(i,:) = horzcat(command_string, A(i,2:len - 5));
    elseif strcmp(A{i, 1},'PAT_CONFIG') == 1
        command_string = {40,i,8,0,31,'1A'};
        command_array(i,:) = horzcat(command_string,A(i, 2:len - 5));
    elseif strcmp(A{i, 1},'PATMEM_LOAD_INIT_MASTER') == 1
        command_string = {40,i,8,0,'2A','1A'};
        command_array(i,:) = horzcat(command_string,A(i, 2:len - 5));
    elseif strcmp(A{i, 1},'PATMEM_LOAD_DATA_MASTER') == 1
        command_string = {40,i,'3A',0,'2B','1A'};
        command_array(i,:) = horzcat(command_string,A(i, 2:len - 5));
    elseif strcmp(A{i, 1},'PAT_START_STOP') == 1
        command_string = {40,i,3,0,24,'1A'};
        command_array(i,:) = horzcat(command_string,A(i, 2:len - 5));
    else
        fprintf('Error within code, TI header not recognized')
    end
end
% Editing the second line of the command_array to stop any pre-existing
% pattern. This means that the TI code MUST have 2 commands sent before
% configuring the LUT
% init_string{1, len} = [];
% init_string(1, 1:7) = {40,2,3,0,24,'1A',0};
% command_array(2,:) = init_string;
% Adding the pattern configuration command to the end of the file
% i = i + 1;
% config_string{1, len} = [];
% config_string(1, 1:12) = {40, i, 8, 0, 31, '1A', 30, 0, 0, 0, 0, 0};
% command_array(i,:) = config_string;
% % Adding the pattern start configuration command to the end of the file
% i = i + 1;
% start_string{1, len} = [];
% start_string(1, 1:7) = {40, i, 3, 0, 24, '1A', 2};
% command_array(i,:) = start_string;
% This final double loop is meant to go through the entire array and edit
% it to an ideal format for the sending. This requires adjusting all
% numerical values to char values to represent HEX code, replacing all
% missing elements of the array with blank elements, and any other issues
for rows = 1:size(command_array, 1)
    for cols = 1:size(command_array, 2)
        if isnumeric(command_array{rows, cols})
            command_array{rows, cols} = num2str(command_array{rows, cols});
        elseif ismissing(command_array{rows, cols})
            command_array{rows, cols} = [];
        end
    end
end

d = DMD('debug', 1);
for idx = 1:size(command_array, 1)
    % Error on hex2dec(data), says that the input argument needs to be a
    % character vector, string, or cell array of character vectors. Perhaps
    % data is being confused when there is no data there? (such as a [])
    % THIS METHOD DEPENDS EXCLUSIVELY ON IF THE SEND FUNCTION TAKES IN A
    % CELL ARRAY OF BINARY THROUGH THE CONNECTION! ENSURE THAT IS TRUE, IT
    % COULD BE JUST A STRING OF BINARY, SOMETHING, WHATEVER THE FUCK IT'S
    % SUPPOSED TO BE
    
    % so, data works when the entire row is filled, but not with []
    % elements
    data_stopper = len;
    for idk = 7:len
        if isnumeric(command_array{idx, idk})
            data_stopper = idk - 1;
            break
        elseif size(command_array{idx, idk}, 1) == 0
            data_stopper = idk - 1;
            break
        end
    end
    data = command_array(idx,7:data_stopper);
    % contains everything except for the byte header?
    % possible issue that the array contains missing elements
    % typecast each individual element to a char?
    data = dec2bin(hex2dec(data),8); 
    cmd = Command();
    cmd.Mode = 'w';                     % set to write mode
    cmd.Reply = true;                   % we want a reply!
    cmd.Sequence = d.getCount;        % set the rolling counter of the sequence byte
    % Adjusted for whatever USB command the command array says it is
    if (strcmp(command_array{idx, 6},'1A') == 1) && (strcmp(command_array{idx, 5}, '1B') == 1)
        % the display mode command 0x1A 0x1B
        cmd.addCommand({'0x1A', '0x1B'}, data);
    elseif (strcmp(command_array{idx, 6},'1A') == 1) && (strcmp(command_array{idx, 5}, '34') == 1)
        % MBOX Data command 0x1A 0x34
        cmd.addCommand({'0x1A', '0x34'}, data);
    elseif (strcmp(command_array{idx, 6},'1A') == 1) && (strcmp(command_array{idx, 5}, '31') == 1)
        % pat config command 0x1A 0x31
        cmd.addCommand({'0x1A', '0x31'}, data);
    elseif (strcmp(command_array{idx, 6},'1A') == 1) && (strcmp(command_array{idx, 5}, '2A') == 1)
        % patmemloadinitmaster command 0x1A 0x2A
        cmd.addCommand({'0x1A', '0x2A'}, data);
    elseif (strcmp(command_array{idx, 6},'1A') == 1) && (strcmp(command_array{idx, 5}, '2B') == 1)
        % patmemloaddatamaster command 0x1A 0x2B
        cmd.addCommand({'0x1A', '0x2B'}, data);
    elseif (strcmp(command_array{idx, 6},'1A') == 1) && (strcmp(command_array{idx, 5}, '24') == 1)
        % pat_start_stop command 0x1A 0x24
        cmd.addCommand({'0x1A', '0x24'}, data);
    else
        fprintf('Error 404: USB command not recognized')
    end
    % usb command seems to utilize the USB command, and then set the data
    % after that, as it takes 2 values: the usb command itself, and the
    % data, which should be in binary format
    d.send(cmd);
    d.receive;
end
toc