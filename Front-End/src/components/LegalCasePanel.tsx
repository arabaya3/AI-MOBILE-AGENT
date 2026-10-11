/**
 * LegalCasePanel — Right-side panel for lawyer workspaces.
 * Shows: practice area tags, case type selector, quick-reference
 * legal topics, court deadline reminder, and a legal disclaimer.
 */
import AccountBalanceRoundedIcon from "@mui/icons-material/AccountBalanceRounded";
import AssignmentRoundedIcon from "@mui/icons-material/AssignmentRounded";
import CalendarMonthRoundedIcon from "@mui/icons-material/CalendarMonthRounded";
import CheckCircleOutlineRoundedIcon from "@mui/icons-material/CheckCircleOutlineRounded";
import FamilyRestroomRoundedIcon from "@mui/icons-material/FamilyRestroomRounded";
import GavelRoundedIcon from "@mui/icons-material/GavelRounded";
import HomeWorkRoundedIcon from "@mui/icons-material/HomeWorkRounded";
import InfoOutlinedIcon from "@mui/icons-material/InfoOutlined";
import LandscapeRoundedIcon from "@mui/icons-material/LandscapeRounded";
import LocalPoliceRoundedIcon from "@mui/icons-material/LocalPoliceRounded";
import PeopleRoundedIcon from "@mui/icons-material/PeopleRounded";
import SchoolRoundedIcon from "@mui/icons-material/SchoolRounded";
import WorkRoundedIcon from "@mui/icons-material/WorkRounded";
import {
  Alert,
  Box,
  Chip,
  Collapse,
  Divider,
  List,
  ListItemButton,
  ListItemIcon,
  ListItemText,
  Stack,
  Typography,
  alpha,
  useTheme,
} from "@mui/material";
import { useState } from "react";

/* ─── Practice-area definitions ─── */
interface PracticeArea {
  key: string;
  label: string;
  icon: React.ReactNode;
  color: string;
  prompts: string[];
}

const PRACTICE_AREAS: PracticeArea[] = [
  {
    key: "civil",
    label: "القانون المدني",
    icon: <AccountBalanceRoundedIcon fontSize="small" />,
    color: "#1565c0",
    prompts: [
      "ما هي عناصر العقد الصحيح وفق القانون المدني الفلسطيني؟",
      "كيف تُحسب التعويضات في دعاوى الضرر المدني؟",
      "ما هي مدد التقادم في الدعاوى المدنية؟",
    ],
  },
  {
    key: "family",
    label: "قانون الأسرة",
    icon: <FamilyRestroomRoundedIcon fontSize="small" />,
    color: "#6a1ade",
    prompts: [
      "ما هي إجراءات الطلاق أمام المحكمة الشرعية؟",
      "كيف تُحدَّد الحضانة وحق الزيارة للأطفال؟",
      "ما هي أحكام المهر والنفقة والعدّة؟",
    ],
  },
  {
    key: "labor",
    label: "قانون العمل",
    icon: <WorkRoundedIcon fontSize="small" />,
    color: "#e65100",
    prompts: [
      "ما هي حقوق العمال في حالة الإنهاء التعسفي للخدمة؟",
      "كيف تُحسب مكافأة نهاية الخدمة والتعويضات؟",
      "ما هي إجراءات تقديم شكوى عمالية لوزارة العمل؟",
    ],
  },
  {
    key: "property",
    label: "قانون الأراضي والعقارات",
    icon: <HomeWorkRoundedIcon fontSize="small" />,
    color: "#2e7d32",
    prompts: [
      "كيف يتم تسجيل الأراضي وتوثيق حق الملكية في دائرة الأراضي؟",
      "ما هي إجراءات الطعن في عقود بيع العقارات المشكوك فيها؟",
      "ما هي أحكام الإيجار والإخلاء في قانون الملكية الفلسطيني؟",
    ],
  },
  {
    key: "criminal",
    label: "الإجراءات الجزائية",
    icon: <LocalPoliceRoundedIcon fontSize="small" />,
    color: "#b71c1c",
    prompts: [
      "ما هي حقوق المتهم في مراحل التحقيق والمحاكمة؟",
      "كيف تُقدَّم شكوى جزائية وما هي مراحل التقاضي الجنائي؟",
      "ما هي الظروف المخففة والمشددة للعقوبة وفق قانون العقوبات؟",
    ],
  },
  {
    key: "land_disputes",
    label: "النزاعات العقارية",
    icon: <LandscapeRoundedIcon fontSize="small" />,
    color: "#795548",
    prompts: [
      "كيف تُعالَج نزاعات الحدود بين قطع الأراضي المتجاورة؟",
      "ما هي إجراءات الطعن في قرارات مصادرة الأراضي؟",
      "ما هي أحكام الشفعة في القانون الفلسطيني؟",
    ],
  },
  {
    key: "inheritance",
    label: "قانون الإرث والوصايا",
    icon: <AssignmentRoundedIcon fontSize="small" />,
    color: "#4527a0",
    prompts: [
      "كيف يتم توزيع التركة وفق أحكام الفقه الإسلامي؟",
      "ما هي شروط صحة الوصية ومتى تُنفّذ؟",
      "كيف تُحل النزاعات بين الورثة أمام المحكمة الشرعية؟",
    ],
  },
  {
    key: "human_rights",
    label: "حقوق الإنسان",
    icon: <PeopleRoundedIcon fontSize="small" />,
    color: "#00838f",
    prompts: [
      "ما هي آليات رفع شكوى انتهاك حقوق الإنسان للهيئات المختصة؟",
      "ما هي حقوق الفرد تجاه السلطات الأمنية وإجراءات الاعتقال؟",
      "كيف يمكن الاستفادة من اتفاقيات حقوق الإنسان الدولية أمام المحاكم؟",
    ],
  },
  {
    key: "administrative",
    label: "القانون الإداري",
    icon: <SchoolRoundedIcon fontSize="small" />,
    color: "#1b5e20",
    prompts: [
      "كيف يتم الطعن في القرارات الإدارية الحكومية؟",
      "ما هي إجراءات الحصول على رخص البناء وتصاريح العمل؟",
      "ما هي صلاحيات ديوان الرقابة المالية والإدارية؟",
    ],
  },
];

/* ─── Court steps ─── */
const COURT_STEPS = [
  { label: "تقديم لائحة الدعوى", done: false },
  { label: "قيد الدعوى ودفع الرسوم", done: false },
  { label: "تبليغ المدعى عليه", done: false },
  { label: "الجلسة الأولى — المرافعة", done: false },
  { label: "تقديم المستندات والأدلة", done: false },
  { label: "صدور الحكم الابتدائي", done: false },
  { label: "الاستئناف (إن لزم)", done: false },
];

/* ─── Component ─── */
interface LegalCasePanelProps {
  onPromptSelect?: (prompt: string) => void;
}

export const LegalCasePanel = ({ onPromptSelect }: LegalCasePanelProps) => {
  const theme = useTheme();
  const [expandedArea, setExpandedArea] = useState<string | null>(null);
  const [completedSteps, setCompletedSteps] = useState<Set<number>>(new Set());
  const [stepsOpen, setStepsOpen] = useState(false);
  const [disclaimerOpen, setDisclaimerOpen] = useState(true);

  const toggleArea = (key: string) =>
    setExpandedArea((prev) => (prev === key ? null : key));

  const toggleStep = (idx: number) =>
    setCompletedSteps((prev) => {
      const next = new Set(prev);
      next.has(idx) ? next.delete(idx) : next.add(idx);
      return next;
    });

  return (
    <Box
      sx={{
        height: "100%",
        overflowY: "auto",
        p: 2,
        display: "flex",
        flexDirection: "column",
        gap: 2,
        bgcolor: theme.palette.mode === "dark" ? "background.paper" : alpha(theme.palette.primary.main, 0.03),
      }}
    >
      {/* ── Header ── */}
      <Stack direction="row" alignItems="center" spacing={1}>
        <GavelRoundedIcon sx={{ color: "primary.main", fontSize: 22 }} />
        <Typography variant="subtitle1" fontWeight={700} color="primary.main">
          مناطق القانون
        </Typography>
      </Stack>
      <Typography variant="caption" color="text.secondary" sx={{ mt: -1.5 }}>
        اختر مجالاً قانونياً لعرض الأسئلة السريعة
      </Typography>

      <Divider />

      {/* ── Practice Areas ── */}
      <List dense disablePadding sx={{ display: "flex", flexDirection: "column", gap: 0.5 }}>
        {PRACTICE_AREAS.map((area) => (
          <Box key={area.key}>
            <ListItemButton
              onClick={() => toggleArea(area.key)}
              selected={expandedArea === area.key}
              sx={{
                borderRadius: 2,
                border: "1px solid",
                borderColor: expandedArea === area.key ? alpha(area.color, 0.4) : "divider",
                bgcolor:
                  expandedArea === area.key
                    ? alpha(area.color, 0.08)
                    : "transparent",
                "&:hover": { bgcolor: alpha(area.color, 0.06) },
                transition: "all 0.15s",
                px: 1.5,
                py: 1,
              }}
            >
              <ListItemIcon
                sx={{
                  minWidth: 34,
                  color: area.color,
                }}
              >
                {area.icon}
              </ListItemIcon>
              <ListItemText
                primary={
                  <Typography variant="body2" fontWeight={600} sx={{ color: expandedArea === area.key ? area.color : "text.primary" }}>
                    {area.label}
                  </Typography>
                }
              />
              <Typography variant="caption" color="text.disabled">
                {expandedArea === area.key ? "▲" : "▼"}
              </Typography>
            </ListItemButton>

            {/* Expanded prompts */}
            <Collapse in={expandedArea === area.key} timeout="auto" unmountOnExit>
              <Stack spacing={0.75} sx={{ mt: 0.75, mb: 0.5, pr: 0.5 }}>
                {area.prompts.map((prompt) => (
                  <Box
                    key={prompt}
                    onClick={() => onPromptSelect?.(prompt)}
                    sx={{
                      p: 1.25,
                      pl: 2,
                      borderRadius: 1.5,
                      border: "1px solid",
                      borderColor: alpha(area.color, 0.2),
                      bgcolor: alpha(area.color, 0.04),
                      cursor: "pointer",
                      "&:hover": {
                        bgcolor: alpha(area.color, 0.12),
                        borderColor: alpha(area.color, 0.5),
                      },
                      transition: "all 0.15s",
                    }}
                  >
                    <Typography variant="caption" lineHeight={1.5} sx={{ color: "text.secondary" }}>
                      {prompt}
                    </Typography>
                  </Box>
                ))}
              </Stack>
            </Collapse>
          </Box>
        ))}
      </List>

      <Divider />

      {/* ── Court Filing Checklist ── */}
      <Box>
        <Stack
          direction="row"
          alignItems="center"
          spacing={1}
          sx={{ cursor: "pointer", userSelect: "none" }}
          onClick={() => setStepsOpen((p) => !p)}
        >
          <CalendarMonthRoundedIcon sx={{ color: "warning.main", fontSize: 20 }} />
          <Typography variant="subtitle2" fontWeight={700}>
            خطوات رفع الدعوى
          </Typography>
          <Chip
            label={`${completedSteps.size}/${COURT_STEPS.length}`}
            size="small"
            color={completedSteps.size === COURT_STEPS.length ? "success" : "warning"}
            sx={{ ml: "auto !important", height: 20, fontSize: "0.65rem" }}
          />
        </Stack>
        <Collapse in={stepsOpen} timeout="auto" unmountOnExit>
          <Stack spacing={0.5} sx={{ mt: 1.25 }}>
            {COURT_STEPS.map((step, idx) => {
              const done = completedSteps.has(idx);
              return (
                <Stack
                  key={idx}
                  direction="row"
                  alignItems="center"
                  spacing={1}
                  sx={{
                    p: 1,
                    borderRadius: 1.5,
                    bgcolor: done ? alpha(theme.palette.success.main, 0.06) : "transparent",
                    cursor: "pointer",
                    "&:hover": { bgcolor: alpha(theme.palette.primary.main, 0.05) },
                    transition: "background 0.15s",
                  }}
                  onClick={() => toggleStep(idx)}
                >
                  <CheckCircleOutlineRoundedIcon
                    sx={{
                      fontSize: 18,
                      color: done ? "success.main" : "text.disabled",
                      flexShrink: 0,
                    }}
                  />
                  <Typography
                    variant="caption"
                    sx={{
                      textDecoration: done ? "line-through" : "none",
                      color: done ? "text.disabled" : "text.primary",
                      lineHeight: 1.4,
                    }}
                  >
                    {step.label}
                  </Typography>
                </Stack>
              );
            })}
          </Stack>
        </Collapse>
      </Box>

      <Divider />

      {/* ── Legal Disclaimer ── */}
      {disclaimerOpen && (
        <Alert
          severity="info"
          icon={<InfoOutlinedIcon fontSize="small" />}
          onClose={() => setDisclaimerOpen(false)}
          sx={{
            fontSize: "0.7rem",
            "& .MuiAlert-message": { fontSize: "0.7rem", lineHeight: 1.5 },
            borderRadius: 2,
          }}
        >
          <Typography variant="caption" lineHeight={1.55} display="block">
            <strong>تنبيه قانوني:</strong> المعلومات المقدمة هنا للأغراض الإعلامية
            فقط ولا تُشكّل استشارة قانونية رسمية. يُنصح بمراجعة محامٍ مرخّص
            للقضايا المعقدة.
          </Typography>
        </Alert>
      )}

      {/* ── Quick contact ── */}
      <Box
        sx={{
          p: 1.5,
          borderRadius: 2,
          border: "1px solid",
          borderColor: alpha(theme.palette.primary.main, 0.2),
          bgcolor: alpha(theme.palette.primary.main, 0.04),
        }}
      >
        <Stack direction="row" alignItems="center" spacing={1} mb={0.5}>
          <GavelRoundedIcon sx={{ color: "primary.main", fontSize: 16 }} />
          <Typography variant="caption" fontWeight={700} color="primary.main">
            نقابة المحامين الفلسطينيين
          </Typography>
        </Stack>
        <Typography variant="caption" color="text.secondary" display="block" lineHeight={1.5}>
          للحصول على محامٍ معتمد، تواصل مع نقابة المحامين الفلسطينيين
          في مدينتك أو عبر بوابة العدالة الرقمية.
        </Typography>
      </Box>
    </Box>
  );
};

export default LegalCasePanel;
