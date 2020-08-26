clear
close all

tic
% So, for this program to run, there are a couple of key factors to consider
% First, we need to load in the text from the TI software, so getting a
% text file
% load('textfile.txt');
% From here, we need to take that testfile and separate out the data within
% it, converting it into a form where it consists of commands we can send
% to the DMD
% this depends on the form of the text file uploaded.
% Essentially, we need to convert between the following formats
% DISP_MODE : 0x03 -> [ 40 1 3 0 1B 1A 3 ]
% in order to accomplish this, it is separated into two elements: we swap
% out the header, and we swap out the package sent.
% the header is represented by the string sent, DISP_MODE here. This is
% equivalent to the first 6 bits of the command string, and we can equate
% them exactly, just accounting for the updated index

% Below creates a cell array of all the individual commands sent out by the TI
% file, edited to properly fit within the format. Not yet formatted to have
% the correct byte size in data upload
A = readcell('first_48_batch_edited.txt');

% Here, we want to read over the entire file to try to determine the number
% of images sent and the number of bytes of compressed data. These numbers
% will be used to determine the size of the command_array, and other
% important factors.
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
num_of_commands = num_of_images + fix(num_of_bytes/54) + 7;

%% BEFORE THE UPLOADING ATTACKED
% Within this section, we convert all of the commands we obtained from the
% cell array A that DO NOT include anything about the upload of the
% compressed data, as that must be handled separately.

% an array of the to-be-converted command strings in the matlab format. The
% maximum number of columns is 62, to fit with the Matlab command length,
% while the number of rows should be 74 + 171 = 245
command_array{num_of_commands, 62} = [];

% So, the for loop below successfully takes in the headers obtained from A
% and converts them to the necessary hexadecimal header for Matlab.
for i = 1:(2 + num_of_images + 1)
    % Here, trying to form the header correctly, so for each possible TI
    % header, we correlate that to the correct HEX input the matlab code
    % provides for us, keeping up the numbering of the commands sent
    % forth.
    if strcmp(A{i, 1},'DISP_MODE') == 1
        % Method below does not work to store header inside of array
        command_string = {40,i,3,0,'1B','1A'};
        command_array(i,:) = horzcat(command_string, A(i,2:57));
    elseif strcmp(A{i, 1},'MBOX_DATA') == 1
        command_string = {40,i,'E',0,34,'1A'};
        command_array(i,:) = horzcat(command_string, A(i,2:57));
    elseif strcmp(A{i, 1},'PAT_CONFIG') == 1
        command_string = {40,i,8,0,31,'1A'};
        command_array(i,:) = horzcat(command_string,A(i, 2:57));
    else
        fprintf('Error within code, TI header not recognized')
    end
end
% Editing the second line of the command_array to stop any pre-existing
% pattern. This means that the TI code MUST have 2 commands sent before
% configuring the LUT
init_string{1, 62} = [];
init_string(1, 1:7) = {40,2,3,0,24,'1A',0};
command_array(2,:) = init_string;
%% THE ASSAULT OF COMPRESSION
% After getting the headers, next, we don't need to convert most of the
% data, have to change the currently blank table to that format. The
% problem comes when converting the 504 data chunks into 54 or less byte
% chunks, how to decrease the size of the lines. Will need to convert the
% 20 lines of data into 171 commands
% So now, we have to take do that conversion. How...unclear

% Below manually selects the lines of code from the converted text file to
% be added to a 1 by X array with all of the data. This method is for the
% specific text file, this must be edited to work with files of different
% sizes/formations, such as more or less images
data = {};
for ii = 53:61
    data = horzcat(data, A{ii, 4:507});
end
data = horzcat(data, A{62, 4:124});

for ii = 64:72
    data = horzcat(data, A{ii, 4:507});
end
data = horzcat(data, A{73, 4:27});

% So, we have a cell array data that contains EVERY byte of compressed
% image data, now we need to cut it into 171 chunks, put a header in front
% of each of those chunks, and append those to the cell array of commands

% The lines below adds the PATMEM_INIT_LOAD_MASTER line into the matlab
% code, with the correct amount of stores bytes. Same format can be used
% for additional individual commands to be added, this is quite robust.
i = i + 1;
init_string{1, 62} = [];
init_string(1, 1:12) = {40,i,8,0,'2A','1A',01, 00, 01, 24, 00, 00};
command_array(i,:) = init_string;

% Forming indexes that will be used for the foor loop and to keep track of
% certain numbers within the loop as well
% data_byte needs to be altered based on the amount of bytes transferred,
% so this form is too specific. Find some way to alter it?
data_byte = num_of_bytes;
jj = 1;
while data_byte > 0
    % Keeping a running index of the command number, so that it doesn't
    % override other commands in their order
    i = i + 1;
    % Creating a blank 64 byte command line to fill with the data obtained
    data_command{1, 62} = [];
    if data_byte > 54
        % Creating the header that will remain consistent across all cases
        % where the command consists of 62 bytes of data
        data_command(1, 1:8) = {40, i, '3A', 0, '2B', '1A', 36, 00};
        % Filling the available space this command can take
        data_command(1, 9:62) = data(1, jj:jj+53);
        % Add command to the total array
        command_array(i,:) = data_command;
        % Decrease count of data by the amount of data taken in this
        % command
        data_byte = data_byte - 54;
        % Increase data index so that next batch is taken from after the
        % previous batch
        jj = jj + 54;
    elseif data_byte < 54
        % The same as the above situation, except modifying it so that the
        % remainder of bytes is successfully modified to fit into a
        % command
        parker = dec2hex(data_byte);
        data_command(1, 1:8) = {40, i, '3A', 0, '2B', '1A', parker, 00};
        data_command(1, 9:9+data_byte - 1) = data(1, jj:jj + data_byte - 1);
        command_array(i,:) = data_command;
        data_byte = data_byte - 54;
    end
end
%% FINAL TOUCHES
% Adding the pattern configuration command to the end of the file
i = i + 1;
config_string{1, 62} = [];
config_string(1, 1:12) = {40, i, 8, 0, 31, '1A', 30, 0, 0, 0, 0, 0};
command_array(i,:) = config_string;
% Adding the pattern start configuration command to the end of the file
i = i + 1;
start_string{1, 62} = [];
start_string(1, 1:7) = {40, i, 3, 0, 24, '1A', 2};
command_array(i,:) = start_string;

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
%% TO THE MEAT GRINDER
% SENDING THE DATA INTO THE DMD
% Open connection to the DMD
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
    data_stopper = 62;
    for idk = 7:62
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
% BOOM