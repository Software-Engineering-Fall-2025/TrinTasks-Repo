# iCal Parser Extension

A Chrome extension that allows you to parse and display event information from iCal (.ics) links.

## Features

- **Parse iCal Links**: Enter any iCal link (HTTPS or HTTP) and the extension will fetch and parse the content
- **Event Details**: Displays comprehensive event information including:
  - Event title
  - Start and end times
  - Location
  - Organizer and attendees
  - Recurrence rules
  - Event description
- **Clean UI**: Modern, user-friendly interface
- **Error Handling**: Clear error messages if the link fails to load or is invalid

## How to Use

1. Click the extension icon in your Chrome toolbar
2. Enter a valid iCal link (URL pointing to a `.ics` file)
3. Click "Parse iCal" or press Enter
4. The extension will fetch and parse the calendar data
5. Events from the iCal file will be displayed in a clean format

## Example iCal Links

You can test the extension with public iCal feeds:
- Google Calendar public links (ends with `.ics`)
- Outlook calendar links
- Any URL that serves iCal format calendar data

## Installation

1. Open Chrome and go to `chrome://extensions/`
2. Enable "Developer mode" in the top right
3. Click "Load unpacked"
4. Navigate to and select the `ical-parser` folder
5. The extension will be loaded and ready to use

## Technical Details

### Parser Support
The extension parses the following iCal fields:
- **SUMMARY**: Event title
- **DESCRIPTION**: Event details
- **LOCATION**: Event location
- **DTSTART**: Event start time
- **DTEND**: Event end time
- **ORGANIZER**: Organizer email
- **ATTENDEE**: Attendee emails
- **RRULE**: Recurrence rules
- **UID**: Unique event identifier

### Supported Date/Time Formats
- `YYYYMMDD` - Date only
- `YYYYMMDDTHHMMSSZ` - UTC datetime
- `YYYYMMDDTHHMMSS` - Local datetime with timezone

## Files Structure

- `manifest.json` - Extension configuration
- `popup.html` - User interface
- `popup.js` - Main application logic with ICalParser and UIController classes
- `styles.css` - Styling for the popup interface

## Notes

- The extension requires fetch permissions for HTTP/HTTPS URLs
- Large calendar files may take a moment to parse
- Times are converted to your local timezone format
- The extension runs entirely in your browser - no data is sent to external servers (except the iCal link you provide)

## Troubleshooting

**"Failed to fetch or parse iCal"**
- Verify the URL is correct and publicly accessible
- Check that it's a valid iCal (.ics) file
- Some calendar services may require authentication

**No events found**
- The iCal file may be empty
- Verify the URL contains valid calendar events

## Version History

### 1.0
- Initial release
- Basic iCal parsing functionality
- Support for common iCal fields
- Error handling and user feedback
