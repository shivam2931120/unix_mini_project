#include <stdio.h>
#include <stdlib.h>
#include <string.h>

#define MAXN 64
typedef struct {
    int pid, at, bt, pr;
    int ct, wt, tat, rem, done;
} P;

static int cmp_at(const void* a, const void* b){ const P *x=a,*y=b; if(x->at!=y->at) return x->at-y->at; return x->pid-y->pid; }
static int cmp_bt(const void* a, const void* b){ const P *x=a,*y=b; if(x->bt!=y->bt) return x->bt-y->bt; return x->pid-y->pid; }
static int cmp_pr(const void* a, const void* b){ const P *x=a,*y=b; if(x->pr!=y->pr) return x->pr-y->pr; return x->pid-y->pid; }

int parse_csv_ints(const char* s, int *arr, int n) {
    int i=0; char buf[4096]; strncpy(buf,s,sizeof(buf)-1); buf[sizeof(buf)-1]='\0';
    char *tok = strtok(buf, ", ");
    while(tok && i<n){ arr[i++] = atoi(tok); tok = strtok(NULL, ", "); }
    return (i==n)?0:-1;
}

int main() {
    // Read inputs prepared by wrapper
    char algo[32]="FCFS";
    int n=0, quantum=1;
    char bursts[4096]="", arrivals[4096]="", prios[4096]="";
    FILE *f = fopen("/tmp/sched_input.txt","r");
    if(!f) return 1;
    fgets(algo, sizeof(algo), f); algo[strcspn(algo,"\n")]=0;
    fscanf(f,"%d\n",&n);
    fgets(bursts,sizeof(bursts),f); bursts[strcspn(bursts,"\n")]=0;
    fgets(arrivals,sizeof(arrivals),f); arrivals[strcspn(arrivals,"\n")]=0;
    fgets(prios,sizeof(prios),f); prios[strcspn(prios,"\n")]=0;
    fscanf(f,"%d",&quantum);
    fclose(f);

    if(n<=0 || n>MAXN){ fprintf(stderr,"Invalid process count.\n"); return 1; }

    P p[MAXN]={0};
    int bt[MAXN]={0}, at[MAXN]={0}, pr[MAXN]={0};
    if(parse_csv_ints(bursts, bt, n)!=0){ fprintf(stderr,"Invalid burst list.\n"); return 1; }
    int have_at = (strlen(arrivals)>0);
    if(have_at && parse_csv_ints(arrivals, at, n)!=0){ fprintf(stderr,"Invalid arrival list.\n"); return 1; }
    int have_pr = (strlen(prios)>0);
    if(have_pr && parse_csv_ints(prios, pr, n)!=0){ fprintf(stderr,"Invalid priority list.\n"); return 1; }

    for(int i=0;i<n;i++){
        p[i].pid=i+1; p[i].bt=bt[i]; p[i].at=have_at?at[i]:0; p[i].pr=have_pr?pr[i]:0;
        p[i].rem=bt[i]; p[i].done=0;
    }

    char gantt[16384]="";
    int time=0, completed=0;
    double sum_wt=0, sum_tat=0;

    if(strcasecmp(algo,"FCFS")==0){
        qsort(p,n,sizeof(P),cmp_at);
        for(int i=0;i<n;i++){
            if(time<p[i].at){ time=p[i].at; }
            char seg[64]; sprintf(seg,"| t=%d P%d ", time, p[i].pid); strcat(gantt,seg);
            time += p[i].bt;
            p[i].ct=time;
            p[i].tat=p[i].ct - p[i].at;
            p[i].wt=p[i].tat - p[i].bt;
            sum_wt+=p[i].wt; sum_tat+=p[i].tat;
        }
    } else if(strcasecmp(algo,"SJF")==0){
        // non-preemptive
        int vis[MAXN]={0}, cur=0; time=0;
        while(completed<n){
            int idx=-1, best=1e9;
            for(int i=0;i<n;i++){
                if(!vis[i] && p[i].at<=time){
                    if(p[i].bt<best){ best=p[i].bt; idx=i; }
                }
            }
            if(idx==-1){ time++; continue; }
            vis[idx]=1;
            char seg[64]; sprintf(seg,"| t=%d P%d ", time, p[idx].pid); strcat(gantt,seg);
            time += p[idx].bt;
            p[idx].ct=time;
            p[idx].tat=p[idx].ct - p[idx].at;
            p[idx].wt=p[idx].tat - p[idx].bt;
            sum_wt+=p[idx].wt; sum_tat+=p[idx].tat; completed++;
        }
    } else if(strcasecmp(algo,"PRIORITY")==0){
        // non-preemptive; lower pr value = higher priority
        int vis[MAXN]={0}; time=0;
        while(completed<n){
            int idx=-1, best=1e9;
            for(int i=0;i<n;i++){
                if(!vis[i] && p[i].at<=time){
                    if(p[i].pr<best){ best=p[i].pr; idx=i; }
                }
            }
            if(idx==-1){ time++; continue; }
            vis[idx]=1;
            char seg[64]; sprintf(seg,"| t=%d P%d ", time, p[idx].pid); strcat(gantt,seg);
            time += p[idx].bt;
            p[idx].ct=time;
            p[idx].tat=p[idx].ct - p[idx].at;
            p[idx].wt=p[idx].tat - p[idx].bt;
            sum_wt+=p[idx].wt; sum_tat+=p[idx].tat; completed++;
        }
    } else { // ROUND ROBIN
        if(quantum<=0) quantum=1;
        // Set time to min arrival
        int min_at = p[0].at; for(int i=1;i<n;i++) if(p[i].at<min_at) min_at=p[i].at;
        time = min_at;
        int left=n;
        while(left>0){
            int progressed=0;
            for(int i=0;i<n;i++){
                if(p[i].rem>0 && p[i].at<=time){
                    int run = (p[i].rem<quantum)?p[i].rem:quantum;
                    char seg[64]; sprintf(seg,"| t=%d P%d ", time, p[i].pid); strcat(gantt,seg);
                    time += run; p[i].rem -= run; progressed=1;
                    if(p[i].rem==0){
                        p[i].ct=time;
                        p[i].tat=p[i].ct - p[i].at;
                        p[i].wt=p[i].tat - p[i].bt;
                        sum_wt+=p[i].wt; sum_tat+=p[i].tat; left--;
                    }
                }
            }
            if(!progressed) time++; // idle gap
        }
    }

    FILE *o=fopen("/tmp/sched_out.txt","w");
    if(!o) return 1;
    fprintf(o,"Algorithm: %s\n\n", algo);
    fprintf(o,"%-6s %-8s %-8s %-9s %-12s %-10s\n","PID","Arrival","Burst","Priority","Waiting","Turnaround");
    for(int i=0;i<n;i++){
        fprintf(o,"P%-5d %-8d %-8d %-9d %-12d %-10d\n", p[i].pid, p[i].at, p[i].bt, p[i].pr, p[i].wt, p[i].tat);
    }
    fprintf(o,"\nAvg Waiting Time: %.2f\nAvg Turnaround Time: %.2f\n\nGantt: %s|\n",
            sum_wt/n, sum_tat/n, gantt);
    fclose(o);
    return 0;
}
