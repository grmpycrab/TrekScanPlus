import { createTheme } from '@mui/material';

const muiTheme = createTheme({
  palette: {
    mode: 'light',
    primary: {
      main:         '#2d6b22',
      light:        '#5aa84a',
      dark:         '#1b4511',
      contrastText: '#ffffff',
    },
    secondary: {
      main:         '#4f5450',
      contrastText: '#ffffff',
    },
    success: { main: '#16a34a', contrastText: '#ffffff' },
    warning: { main: '#d97706', contrastText: '#ffffff' },
    error:   { main: '#dc2626', contrastText: '#ffffff' },
    info:    { main: '#2563eb', contrastText: '#ffffff' },
    background: {
      default: '#f3f5f2',
      paper:   '#ffffff',
    },
    text: {
      primary:   '#1a1f1a',
      secondary: '#4f5450',
      disabled:  '#9ea39b',
    },
    divider: '#e3e6e1',
    grey: {
      50:  '#f8faf7',
      100: '#f1f3ef',
      200: '#e3e6e1',
      300: '#cdd1ca',
      400: '#9ea39b',
      500: '#6b706a',
      600: '#50554f',
      700: '#383c37',
      800: '#242824',
      900: '#131513',
    },
  },

  typography: {
    fontFamily: "'Poppins', 'Inter', -apple-system, sans-serif",
    h1: { fontWeight: 700, lineHeight: 1.15 },
    h2: { fontWeight: 700, lineHeight: 1.2 },
    h3: { fontWeight: 600, lineHeight: 1.25 },
    h4: { fontWeight: 600, lineHeight: 1.3 },
    h5: { fontWeight: 600, lineHeight: 1.4 },
    h6: { fontWeight: 600, lineHeight: 1.4 },
    subtitle1: { fontWeight: 500 },
    subtitle2: { fontWeight: 500, fontSize: '0.8125rem' },
    body1:    { fontSize: '0.9375rem', lineHeight: 1.6 },
    body2:    { fontSize: '0.875rem',  lineHeight: 1.6 },
    caption:  { fontSize: '0.75rem',   lineHeight: 1.5 },
    overline: { fontSize: '0.6875rem', fontWeight: 600, letterSpacing: '0.08em' },
    button:   { fontWeight: 500, textTransform: 'none', letterSpacing: '0.01em' },
  },

  shape: { borderRadius: 8 },

  shadows: [
    'none',
    '0 1px 2px rgba(0,0,0,0.04)',
    '0 1px 3px rgba(0,0,0,0.06), 0 1px 2px rgba(0,0,0,0.04)',
    '0 4px 12px rgba(0,0,0,0.07), 0 1px 4px rgba(0,0,0,0.04)',
    '0 8px 24px rgba(0,0,0,0.08)',
    '0 16px 40px rgba(0,0,0,0.10)',
    ...Array(19).fill('0 4px 12px rgba(0,0,0,0.07)'),
  ],

  components: {
    MuiButton: {
      defaultProps: { disableElevation: true },
      styleOverrides: {
        root: {
          borderRadius: 8,
          fontWeight: 500,
          textTransform: 'none',
          letterSpacing: '0.01em',
          padding: '8px 16px',
        },
        sizeLarge:  { padding: '10px 20px', fontSize: '0.9375rem' },
        sizeSmall:  { padding: '5px 12px',  fontSize: '0.8125rem' },
        contained:  { boxShadow: 'none', '&:hover': { boxShadow: 'none' } },
        outlined: {
          borderColor: '#cdd1ca',
          '&:hover': { borderColor: '#9ea39b', background: '#f8faf7' },
        },
      },
    },

    MuiCard: {
      styleOverrides: {
        root: {
          boxShadow: '0 1px 3px rgba(0,0,0,0.06)',
          borderRadius: 12,
          border: '1px solid #e3e6e1',
        },
      },
    },

    MuiPaper: {
      styleOverrides: {
        root: { backgroundImage: 'none' },
        rounded: { borderRadius: 12 },
        elevation1: { boxShadow: '0 1px 3px rgba(0,0,0,0.06)' },
        elevation2: { boxShadow: '0 4px 12px rgba(0,0,0,0.07)' },
        elevation3: { boxShadow: '0 8px 24px rgba(0,0,0,0.08)' },
      },
    },

    MuiChip: {
      styleOverrides: {
        root: {
          fontWeight: 500,
          fontSize: '0.75rem',
          height: 26,
          borderRadius: 6,
        },
      },
    },

    MuiTextField: {
      styleOverrides: {
        root: {
          '& .MuiOutlinedInput-root': {
            borderRadius: 8,
            backgroundColor: '#f8faf7',
            '& fieldset': { borderColor: '#e3e6e1' },
            '&:hover fieldset': { borderColor: '#9ea39b' },
            '&.Mui-focused fieldset': { borderColor: '#2d6b22', borderWidth: 1.5 },
          },
        },
      },
    },

    MuiOutlinedInput: {
      styleOverrides: {
        root: { borderRadius: 8 },
        notchedOutline: { borderColor: '#e3e6e1' },
      },
    },

    MuiTableCell: {
      styleOverrides: {
        head: {
          fontWeight: 600,
          fontSize: '0.75rem',
          textTransform: 'uppercase',
          letterSpacing: '0.06em',
          color: '#4f5450',
          backgroundColor: '#f8faf7',
          borderBottom: '1px solid #e3e6e1',
        },
        body: {
          fontSize: '0.875rem',
          color: '#1a1f1a',
          borderBottom: '1px solid #f1f3ef',
        },
      },
    },

    MuiTableRow: {
      styleOverrides: {
        root: {
          '&:hover td': { backgroundColor: '#f8faf7' },
          '&:last-child td': { borderBottom: 'none' },
        },
      },
    },

    MuiDivider: {
      styleOverrides: {
        root: { borderColor: '#e3e6e1' },
      },
    },

    MuiIconButton: {
      styleOverrides: {
        root: {
          borderRadius: 8,
          transition: 'background 140ms ease',
          '&:hover': { background: '#f1f3ef' },
        },
      },
    },

    MuiTooltip: {
      styleOverrides: {
        tooltip: {
          backgroundColor: '#1a1f1a',
          fontSize: '0.75rem',
          fontWeight: 500,
          borderRadius: 6,
          padding: '6px 10px',
        },
        arrow: { color: '#1a1f1a' },
      },
    },

    MuiDialog: {
      styleOverrides: {
        paper: {
          borderRadius: 16,
          boxShadow: '0 16px 40px rgba(0,0,0,0.12)',
        },
      },
    },

    MuiDialogTitle: {
      styleOverrides: {
        root: { fontWeight: 600, fontSize: '1.0625rem', padding: '20px 24px 12px' },
      },
    },

    MuiDialogContent: {
      styleOverrides: {
        root: { padding: '12px 24px' },
      },
    },

    MuiDialogActions: {
      styleOverrides: {
        root: { padding: '16px 24px 20px', gap: 8 },
      },
    },

    MuiTabs: {
      styleOverrides: {
        root: { minHeight: 42 },
        indicator: { height: 2, borderRadius: 2 },
      },
    },

    MuiTab: {
      styleOverrides: {
        root: {
          fontWeight: 500,
          fontSize: '0.875rem',
          minHeight: 42,
          textTransform: 'none',
          letterSpacing: '0',
          padding: '8px 16px',
        },
      },
    },

    MuiBadge: {
      styleOverrides: {
        badge: {
          fontSize: '0.6875rem',
          fontWeight: 600,
          minWidth: 18,
          height: 18,
          padding: '0 5px',
        },
      },
    },
  },
});

export default muiTheme;
