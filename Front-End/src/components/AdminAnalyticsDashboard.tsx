import { useState, useEffect } from "react";
import {
  Box,
  Card,
  CardContent,
  Typography,
  CircularProgress,
  Stack,
  useTheme,
  alpha,
  Table,
  TableBody,
  TableCell,
  TableHead,
  TableRow,
  Button,
} from "@mui/material";
import { TrendingUp, Group, Message, Storage, Token, AttachMoney, Speed, CheckCircle, Refresh } from "@mui/icons-material";
import { BarChart, Bar, PieChart, Pie, Cell, XAxis, YAxis, CartesianGrid, Tooltip, Legend, ResponsiveContainer } from "recharts";
import { getAdminDashboardStats, getSpaceDashboardStats, type DashboardStats } from "../api/spaces";

const COLORS = ["#2563eb", "#7c3aed", "#db2777", "#ea580c", "#ca8a04", "#16a34a", "#0891b2"];

interface AdminAnalyticsDashboardProps {
  data?: any;
  loading?: boolean;
  onOpenSpace?: (spaceId: string) => void;
  spaceId?: string;
}

export const AdminAnalyticsDashboard = ({ onOpenSpace, spaceId }: AdminAnalyticsDashboardProps) => {
  const theme = useTheme();
  const [loading, setLoading] = useState(true);
  const [stats, setStats] = useState<DashboardStats | null>(null);
  const [error, setError] = useState<string | null>(null);

  useEffect(() => {
    loadDashboardData();
  }, [spaceId]);

  const loadDashboardData = async () => {
    setLoading(true);
    setError(null);
    try {
      const data = spaceId 
        ? await getSpaceDashboardStats(spaceId)
        : await getAdminDashboardStats();
      setStats(data);
    } catch (error) {
       console.error("Failed to load dashboard data:", error);
       setError("تعذّر تحميل البيانات. ربما ليس لديك صلاحية الوصول.");
    } finally {
      setLoading(false);
    }
  };

  if (loading) {
    return (
      <Box display="flex" justifyContent="center" alignItems="center" minHeight="400px">
        <CircularProgress />
      </Box>
    );
  }

  if (error) {
    return (
      <Box display="flex" flexDirection="column" gap={2} justifyContent="center" alignItems="center" minHeight="400px">
        <Typography color="error">{error}</Typography>
        <Button startIcon={<Refresh />} onClick={loadDashboardData}>
          إعادة المحاولة
        </Button>
      </Box>
    );
  }

  if (!stats) return null;

  const MetricCard = ({ title, value, subtitle, icon: Icon, color }: any) => (
    <Card sx={{ height: "100%", background: `linear-gradient(135deg, ${alpha(color, 0.1)} 0%, ${alpha(color, 0.05)} 100%)`, border: `1px solid ${alpha(color, 0.2)}` }}>
      <CardContent>
        <Stack direction="row" justifyContent="space-between" alignItems="flex-start">
          <Box>
            <Typography variant="caption" color="text.secondary" fontWeight={600}>
              {title}
            </Typography>
            <Typography variant="h4" fontWeight={700} sx={{ my: 1, color }}>
              {value}
            </Typography>
            <Typography variant="caption" color="text.secondary">
              {subtitle}
            </Typography>
          </Box>
          <Box sx={{ backgroundColor: alpha(color, 0.1), borderRadius: 2, p: 1.5, display: "flex", alignItems: "center", justifyContent: "center" }}>
            <Icon sx={{ color, fontSize: 32 }} />
          </Box>
        </Stack>
      </CardContent>
    </Card>
  );

  return (
    <Box sx={{ p: 3 }}>
      <Stack direction="row" justifyContent="space-between" alignItems="center" mb={3}>
        <Box>
          <Typography variant="h4" fontWeight={700}>
          لوحة التحكّم الإدارية
          </Typography>
          <Typography variant="body2" color="text.secondary">
            تحليلات شاملة ورؤى نظامية
          </Typography>
        </Box>
        <Button startIcon={<Refresh />} onClick={loadDashboardData}>
          تحديث
        </Button>
      </Stack>

      <Box
        sx={{
          display: "grid",
          gap: 2,
          gridTemplateColumns: { xs: "1fr", sm: "repeat(2, 1fr)", md: "repeat(4, 1fr)" },
        }}
        mb={3}
      >
        <MetricCard
          title="إجمالي المستخدمين"
          value={stats.total_users.toLocaleString()}
          subtitle="مستخدمون مسجّلون"
          icon={Group}
          color="#2563eb"
        />
        <MetricCard
          title="إجمالي الرسائل"
          value={stats.total_messages.toLocaleString()}
          subtitle="منذ نشأة المنصّة"
          icon={Message}
          color="#7c3aed"
        />
        <MetricCard
          title="إجمالي الرموز"
          value={(stats.total_tokens / 1_000_000).toFixed(2) + "M"}
          subtitle="الاستخدام الكلي"
          icon={Token}
          color="#db2777"
        />
        <MetricCard
          title="إجمالي التكلفة"
          value={`$${stats.total_cost.toFixed(2)}`}
          subtitle="التكلفة الكلية"
          icon={AttachMoney}
          color="#ea580c"
        />
      </Box>

      <Box
        sx={{
          display: "grid",
          gap: 2,
          gridTemplateColumns: { xs: "1fr", sm: "repeat(2, 1fr)", md: "repeat(4, 1fr)" },
        }}
        mb={3}
      >
        <MetricCard
          title="متوسّط الاستجابة"
          value={`${stats.avg_response_time}s`}
          subtitle="تأخير النظام"
          icon={Speed}
          color="#ca8a04"
        />
        <MetricCard
          title="نسبة النجاح"
          value={`${stats.success_rate}%`}
          subtitle="عالمي"
          icon={CheckCircle}
          color="#16a34a"
        />
        <MetricCard
          title="الجلسات النشطة"
          value={stats.active_spaces}
          subtitle="جلسات"
          icon={Storage}
          color="#0891b2"
        />
        <MetricCard
          title="أكثر نموذج استخداماً"
          value={stats.top_models[0]?.name || "غير متاح"}
          subtitle="الأكثر استخداماً"
          icon={TrendingUp}
          color="#2563eb"
        />
      </Box>

      <Box
        sx={{
          display: "grid",
          gap: 2,
          gridTemplateColumns: { xs: "1fr", sm: "repeat(2, 1fr)", md: "repeat(4, 1fr)" },
        }}
        mb={3}
      >
        <MetricCard
          title="إجمالي الجلسات"
          value={stats.total_sessions.toLocaleString()}
          subtitle="منذ نشأة المنصّة"
          icon={Message}
          color="#4f46e5"
        />
        <MetricCard
          title="المستندات"
          value={stats.total_documents.toLocaleString()}
          subtitle="مستندات محفوظة"
          icon={Storage}
          color="#0f766e"
        />
        <MetricCard
          title="الطلبات"
          value={stats.total_requests.toLocaleString()}
          subtitle="جميع أنواع الطلبات"
          icon={TrendingUp}
          color="#be123c"
        />
        <MetricCard
          title="مستخدمون جدد (30 يوم)"
          value={stats.new_users_30d.toLocaleString()}
          subtitle="اشتراكات حديثة"
          icon={Group}
          color="#2563eb"
        />
        <MetricCard
          title="مستخدمون نشطون (30 يوم)"
          value={stats.active_users_30d.toLocaleString()}
          subtitle="نشطون مؤخراً"
          icon={Group}
          color="#16a34a"
        />
        <MetricCard
          title="المشرفون"
          value={stats.admins_count.toLocaleString()}
          subtitle="أدوار إدارية"
          icon={Group}
          color="#7c3aed"
        />
        <MetricCard
          title="الأعضاء"
          value={stats.members_count.toLocaleString()}
          subtitle="أدوار الأعضاء"
          icon={Group}
          color="#0ea5e9"
        />
      </Box>

      <Box sx={{ display: "grid", gap: 2, gridTemplateColumns: { xs: "1fr", lg: "2fr 1fr" } }}>
        <Card>
          <CardContent>
            <Typography variant="h6" fontWeight={700} mb={2}>
              أعلى استخداماً للجلسات
            </Typography>
            <ResponsiveContainer width="100%" height={300}>
              <BarChart data={stats.usage_by_space}>
                <CartesianGrid strokeDasharray="3 3" stroke={theme.palette.divider} />
                <XAxis dataKey="space_name" tick={{ fontSize: 12 }} />
                <YAxis yAxisId="left" tick={{ fontSize: 12 }} />
                <YAxis yAxisId="right" orientation="right" tick={{ fontSize: 12 }} />
                <Tooltip
                  contentStyle={{
                    backgroundColor: theme.palette.background.paper,
                    border: `1px solid ${theme.palette.divider}`,
                    borderRadius: 8,
                  }}
                />
                <Legend />
                <Bar yAxisId="left" dataKey="tokens" fill="#2563eb" name="الرموز" radius={[8, 8, 0, 0]} />
                <Bar yAxisId="right" dataKey="cost" fill="#7c3aed" name="التكلفة ($)" radius={[8, 8, 0, 0]} />
              </BarChart>
            </ResponsiveContainer>
          </CardContent>
        </Card>

        <Card sx={{ height: "100%" }}>
          <CardContent>
            <Typography variant="h6" fontWeight={700} mb={2}>
              توزيع التكلفة
            </Typography>
            <ResponsiveContainer width="100%" height={300}>
              <PieChart>
                <Pie
                  data={stats.usage_by_space.slice(0, 7)}
                  dataKey="cost"
                  nameKey="space_name"
                  cx="50%"
                  cy="50%"
                  outerRadius={80}
                  label={(entry) => `$${entry.value.toFixed(2)}`}
                >
                  {stats.usage_by_space.slice(0, 7).map((_entry, index) => (
                    <Cell key={`cell-${index}`} fill={COLORS[index % COLORS.length]} />
                  ))}
                </Pie>
                <Tooltip
                  contentStyle={{
                    backgroundColor: theme.palette.background.paper,
                    border: `1px solid ${theme.palette.divider}`,
                    borderRadius: 8,
                  }}
                />
                <Legend />
              </PieChart>
            </ResponsiveContainer>
          </CardContent>
        </Card>
      </Box>

      {/* Spaces List Table */}
      <Card sx={{ mt: 3 }}>
        <CardContent>
          <Typography variant="h6" fontWeight={700} mb={2}>
            Top Active Spaces
          </Typography>

          {/* Mobile: card list */}
          <Stack spacing={1.25} sx={{ display: { xs: "flex", md: "none" } }}>
            {stats.usage_by_space.map((row) => (
              <Card key={row.space_id} variant="outlined" sx={{ borderRadius: 2 }}>
                <CardContent sx={{ p: 2.25, "&:last-child": { pb: 2.25 } }}>
                  <Stack spacing={1}>
                    <Stack spacing={0.25}>
                      <Typography fontWeight={800}>{row.space_name}</Typography>
                      <Typography variant="caption" color="text.secondary" sx={{ wordBreak: "break-all" }}>
                        {row.space_id}
                      </Typography>
                    </Stack>

                    <Stack direction="row" spacing={2} justifyContent="space-between">
                      <Stack spacing={0.25}>
                        <Typography variant="caption" color="text.secondary">الطلبات</Typography>
                        <Typography fontWeight={700}>{row.requests.toLocaleString()}</Typography>
                      </Stack>
                      <Stack spacing={0.25}>
                        <Typography variant="caption" color="text.secondary">الرموز</Typography>
                        <Typography fontWeight={700}>{row.tokens.toLocaleString()}</Typography>
                      </Stack>
                      <Stack spacing={0.25}>
                        <Typography variant="caption" color="text.secondary">التكلفة</Typography>
                        <Typography fontWeight={700}>${row.cost.toFixed(2)}</Typography>
                      </Stack>
                    </Stack>

                    {onOpenSpace ? (
                      <Button size="small" variant="outlined" onClick={() => onOpenSpace(row.space_id)} sx={{ alignSelf: "flex-end" }}>
                        إدارة
                      </Button>
                    ) : null}
                  </Stack>
                </CardContent>
              </Card>
            ))}
          </Stack>

          {/* Desktop: table */}
          <Box sx={{ display: { xs: "none", md: "block" }, overflowX: "auto" }}>
            <Table size="small" sx={{ minWidth: 760 }}>
              <TableHead>
                <TableRow>
                  <TableCell>اسم الجلسة</TableCell>
                  <TableCell>المعرّف</TableCell>
                  <TableCell align="right">الطلبات</TableCell>
                  <TableCell align="right">الرموز</TableCell>
                  <TableCell align="right">التكلفة ($)</TableCell>
                  <TableCell align="right">إجراء</TableCell>
                </TableRow>
              </TableHead>
              <TableBody>
                {stats.usage_by_space.map((row) => (
                  <TableRow key={row.space_id} hover>
                    <TableCell sx={{ fontWeight: 700 }}>{row.space_name}</TableCell>
                    <TableCell sx={{ color: "text.secondary", fontSize: "0.75rem" }}>{row.space_id}</TableCell>
                    <TableCell align="right">{row.requests.toLocaleString()}</TableCell>
                    <TableCell align="right">{row.tokens.toLocaleString()}</TableCell>
                    <TableCell align="right">{row.cost.toFixed(2)}</TableCell>
                    <TableCell align="right">
                      {onOpenSpace && (
                        <Button size="small" variant="outlined" onClick={() => onOpenSpace(row.space_id)}>
                          إدارة
                        </Button>
                      )}
                    </TableCell>
                  </TableRow>
                ))}
              </TableBody>
            </Table>
          </Box>
        </CardContent>
      </Card>
    </Box>
  );
};

export default AdminAnalyticsDashboard;
