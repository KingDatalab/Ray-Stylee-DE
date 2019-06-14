ld(f.surv.flw)
library(Matrix)
library(survival)
library(survutils)
f.surv.flw[, tag := ifelse(date - as.Date(follow.date) > 0, 1, 0), keyby = .(cube.symbol, stck)
    ][, first.half := ifelse(tag == 0, 1, 0)
    ][, second.half := ifelse(tag == 1, 1, 0)
    ][, loss := ifelse(gain == 1, 0, 1)
    ][, ishold := ifelse(issale == 1, 0, 1)] # sign the two-stage and loss&hold data

# As the robust test in rbst1, selecting the individuals before and after follow both have trade-offs.
f.surv.early <- f.surv.flw[first.half == 1]
f.surv.late <- f.surv.flw[second.half == 1]

f.cube.early <- f.surv.early[, .(cube.symbol = unique(cube.symbol))]
f.cube.late <- f.surv.late[, .(cube.symbol = unique(cube.symbol))]
f.cube <- f.cube.early[f.cube.late, on = "cube.symbol", nomatch = 0]

f.rbst1 <- f.surv.flw[f.cube, on = "cube.symbol", nomatch = 0]
f.rbst1.early <- f.rbst1[first.half == 1]
f.rbst1.late <- f.rbst1[second.half == 1]

rm(f.cube.early, f.cube.late, f.cube)

# Calculate DE of every individual before and after following
DEbeta.e <- f.rbst1.early[, .(Prefollow = lm(issale ~ gain) %>% coef()), by = .(cube.symbol)
    ][, .SD[2], by = .(cube.symbol)]
DEbeta.l <- f.rbst1.late[, .(Postfollow = lm(issale ~ gain) %>% coef()), by = .(cube.symbol)
    ][, .SD[2], by = .(cube.symbol)]
DEbeta <- DEbeta.e[DEbeta.l, on = "cube.symbol"]

# T-test between pre and pro following and plot the comparing DE
rst.t.test <- DEbeta[!is.na(Prefollow) & !is.na(Postfollow), t.test(Profollow, Prefollow)]
ggDE <- melt(DEbeta[!is.na(Prefollow) & !is.na(Postfollow) & Prefollow], id.vars = c("cube.symbol"), measure.vars = c("Prefollow", "Postfollow"))
setnames(ggDE, 2:3, c("Stage", "Coefficient"))
d.ttest <- ggplot(ggDE, aes(x = Coefficient, colour = Stage)) + geom_line(stat = "density") + theme_grey() + scale_colour_manual(values = c("#CC6666", "#7777DD"))
ggsave(d.ttest, device = "eps")